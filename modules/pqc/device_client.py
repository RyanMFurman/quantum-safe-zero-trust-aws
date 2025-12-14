import os
import time
import json
import boto3
import requests
from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.x509.oid import NameOID, ObjectIdentifier

# Kyber implementation
from kyber_pure import PureKyber512


# CONFIGURATION

DEVICE_ID = "device15test"
BUCKET = "quantum-safe-artifacts-dev"

CSR_KEY = f"csr/{DEVICE_ID}.csr"
CRT_KEY = f"csr/{DEVICE_ID}.crt"
META_KEY = f"csr/{DEVICE_ID}.json"

API_URL = "https://cvv14bi0b0.execute-api.us-east-1.amazonaws.com/dev/onboard"

# Custom OID for PQC Kyber512 public key embedding
PQC_OID = ObjectIdentifier("1.3.6.1.4.1.99999.1.1")

s3 = boto3.client("s3")

# 1. Generate RSA keypair

print("Generating RSA keypair...")
rsa_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)


# 2. Generate Kyber PQC keys

print("Generating Kyber512 PQC keypair...")
pqc_pk, pqc_sk = PureKyber512.keygen()


# 3. Build CSR embedding PQC public key

csr = (
    x509.CertificateSigningRequestBuilder()
    .subject_name(
        x509.Name([
            x509.NameAttribute(NameOID.COMMON_NAME, DEVICE_ID),
        ])
    )
    .add_extension(
        x509.UnrecognizedExtension(
            oid=PQC_OID,
            value=pqc_pk  # raw bytes of Kyber public key
        ),
        critical=False
    )
    .sign(rsa_key, hashes.SHA256())
)

csr_pem = csr.public_bytes(serialization.Encoding.PEM)


# 4. Call onboarding API

print("Calling onboarding API...")
resp = requests.post(API_URL, json={"device_id": DEVICE_ID})
print("API response:", resp.text)

# 5. Upload CSR to S3

print(f"Uploading CSR → s3://{BUCKET}/{CSR_KEY}")
s3.put_object(Bucket=BUCKET, Key=CSR_KEY, Body=csr_pem)

# 6. Wait for certificate issuance

print("Waiting for certificate issuance...")
cert_pem = None

for _ in range(25):
    try:
        crt_obj = s3.get_object(Bucket=BUCKET, Key=CRT_KEY)
        cert_pem = crt_obj["Body"].read().decode()
        print("✔ Certificate retrieved")
        break
    except:
        time.sleep(1)

if cert_pem is None:
    raise RuntimeError("Timed out waiting for certificate")

# 7. Save keys + certs locally

with open("device.key", "wb") as f:
    f.write(
        rsa_key.private_bytes(
            serialization.Encoding.PEM,
            serialization.PrivateFormat.TraditionalOpenSSL,
            serialization.NoEncryption(),
        )
    )

with open("device.crt", "w") as f:
    f.write(cert_pem)

with open("device_pqc.pk", "wb") as f:
    f.write(pqc_pk)

with open("device_pqc.sk", "wb") as f:
    f.write(pqc_sk)


# 8. Fetch metadata from S3
meta = s3.get_object(Bucket=BUCKET, Key=META_KEY)["Body"].read().decode()

print("\nMetadata:", meta)
print("\nDevice onboarding + PQC key provisioning complete!\n")
