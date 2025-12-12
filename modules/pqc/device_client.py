import os
import time
import json
import boto3
import requests
from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.x509.oid import NameOID

# ============================
# CONFIGURATION
# ============================

DEVICE_ID = "device15test"               # Change per test
BUCKET = "quantum-safe-artifacts-dev"    # Same S3 bucket Lambda writes to

CSR_KEY = f"csr/{DEVICE_ID}.csr"
CRT_KEY = f"csr/{DEVICE_ID}.crt"
META_KEY = f"csr/{DEVICE_ID}.json"

# Device onboarding endpoint (API Gateway)
API_URL = "https://cvv14bi0b0.execute-api.us-east-1.amazonaws.com/dev/onboard"

s3 = boto3.client("s3")

# ============================
# 1. Generate private key
# ============================

print("Generating RSA private key...")
key = rsa.generate_private_key(
    public_exponent=65537,
    key_size=2048,
)

# ============================
# 2. Build CSR for the device
# ============================

csr = (
    x509.CertificateSigningRequestBuilder()
    .subject_name(
        x509.Name([
            x509.NameAttribute(NameOID.COMMON_NAME, DEVICE_ID),
        ])
    )
    .sign(key, hashes.SHA256())
)

csr_pem = csr.public_bytes(serialization.Encoding.PEM)

# ============================
# 3. Register device via onboarding API
# ============================

print("Calling onboarding API...")
resp = requests.post(API_URL, json={"device_id": DEVICE_ID})
print("API response:", resp.text)

if resp.status_code != 200:
    raise Exception("Onboarding API failed")

# ============================
# 4. Upload CSR → S3
# ============================

print(f"Uploading CSR to S3 → s3://{BUCKET}/{CSR_KEY}")
s3.put_object(Bucket=BUCKET, Key=CSR_KEY, Body=csr_pem)

# ============================
# 5. Poll for certificate
# ============================

print("Waiting for certificate to be issued...")

cert_pem = None

for attempt in range(40):  # ~40 seconds max wait
    try:
        crt_obj = s3.get_object(Bucket=BUCKET, Key=CRT_KEY)
        cert_pem = crt_obj["Body"].read().decode()
        print("✅ Certificate retrieved!")
        break
    except Exception:
        time.sleep(1)

if cert_pem is None:
    raise Exception("Timed out waiting for certificate")

# ============================
# 6. Save device files locally
# ============================

with open("device.key", "wb") as f:
    f.write(
        key.private_bytes(
            serialization.Encoding.PEM,
            serialization.PrivateFormat.TraditionalOpenSSL,
            serialization.NoEncryption()
        )
    )

with open("device.crt", "w") as f:
    f.write(cert_pem)

print("Saved device.key and device.crt")

# ============================
# 7. Download metadata JSON
# ============================

meta_raw = s3.get_object(Bucket=BUCKET, Key=META_KEY)["Body"].read().decode()
metadata = json.loads(meta_raw)

print("Metadata:", json.dumps(metadata, indent=2))
print("\n🎉 Device onboarding + certificate issuance complete!")
