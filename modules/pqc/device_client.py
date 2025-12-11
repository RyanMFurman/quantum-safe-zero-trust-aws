import os
import time
import json
import boto3
import requests
from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.x509.oid import NameOID

# CONFIG
DEVICE_ID = "device15test"
BUCKET = "quantum-safe-artifacts-dev"
CSR_KEY = f"csr/{DEVICE_ID}.csr"
CRT_KEY = f"csr/{DEVICE_ID}.crt"
META_KEY = f"csr/{DEVICE_ID}.json"

API_URL = "https://cvv14bi0b0.execute-api.us-east-1.amazonaws.com/dev/onboard"

s3 = boto3.client("s3")

# 1. Generate RSA private key
print("Generating RSA keypair...")
key = rsa.generate_private_key(public_exponent=65537, key_size=2048)

# 2. Create CSR
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

# 3. Step 1: Call onboarding API
print("Calling onboarding API...")
resp = requests.post(API_URL, json={"device_id": DEVICE_ID})
print("API response:", resp.text)

# 4. Upload CSR manually (for now, replicating device behavior)
print("Uploading CSR to S3...")
s3.put_object(Bucket=BUCKET, Key=CSR_KEY, Body=csr_pem)

# 5. Poll S3 until certificate generated
print("Waiting for certificate to be issued...")
for i in range(20):
    try:
        crt_obj = s3.get_object(Bucket=BUCKET, Key=CRT_KEY)
        cert_pem = crt_obj["Body"].read().decode()
        print("Certificate retrieved!")
        break
    except:
        time.sleep(1)

# 6. Save local files
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

# 7. Get Metadata
meta = s3.get_object(Bucket=BUCKET, Key=META_KEY)["Body"].read().decode()
print("Metadata:", meta)
