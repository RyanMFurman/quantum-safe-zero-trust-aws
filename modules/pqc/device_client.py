import os
import time
import json
import boto3
import requests
import argparse

from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import rsa, padding
from cryptography.x509.oid import NameOID
from cryptography.x509 import ObjectIdentifier

from asn1crypto.core import OctetString
from kyber_pure import PureKyber512


#         CLI ARGUMENTS

parser = argparse.ArgumentParser()
parser.add_argument("--mode", required=True, choices=["onboard", "attest"])
parser.add_argument("--device-id", required=True)
args = parser.parse_args()

DEVICE_ID = args.device_id

#          CONFIG

BUCKET = "quantum-safe-artifacts-dev"

CSR_KEY = f"csr/{DEVICE_ID}.csr"
CRT_KEY = f"csr/{DEVICE_ID}.crt"
META_KEY = f"csr/{DEVICE_ID}.json"

API_URL = "https://7fokf339cj.execute-api.us-east-1.amazonaws.com/dev/onboard"
ATTEST_URL = "https://7fokf339cj.execute-api.us-east-1.amazonaws.com/dev/attest"

PQC_OID = ObjectIdentifier("1.3.6.1.4.1.99999.1.1")

s3 = boto3.client("s3")


#      LOCAL DEVICE KEYS


RSA_KEY_PATH = "device_rsa_key.pem"
PK_PATH = "device_pqc.pk"
SK_PATH = "device_pqc.sk"


# -------- Load or generate RSA key --------

if os.path.exists(RSA_KEY_PATH):
    print("Loading existing RSA keypair...")
    with open(RSA_KEY_PATH, "rb") as f:
        rsa_key = serialization.load_pem_private_key(f.read(), None)
else:
    print("Generating new RSA keypair...")
    rsa_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    with open(RSA_KEY_PATH, "wb") as f:
        f.write(
            rsa_key.private_bytes(
                serialization.Encoding.PEM,
                serialization.PrivateFormat.TraditionalOpenSSL,
                serialization.NoEncryption(),
            )
        )
    print("Saved:", RSA_KEY_PATH)


# -------- Load or generate Kyber512 PQC keys --------

if os.path.exists(PK_PATH) and os.path.exists(SK_PATH):
    print("Loading existing Kyber512 PQC keys...")
    with open(PK_PATH, "rb") as f:
        pqc_pk = f.read()
    with open(SK_PATH, "rb") as f:
        pqc_sk = f.read()
else:
    print("Generating new Kyber512 PQC keypair...")
    pqc_pk, pqc_sk = PureKyber512.keygen()
    with open(PK_PATH, "wb") as f:
        f.write(pqc_pk)
    with open(SK_PATH, "wb") as f:
        f.write(pqc_sk)
    print("Saved PQC keys:", PK_PATH, SK_PATH)


#      BUILD CSR + EXTENSION

print("\nBuilding CSR with PQC extension...")

lvl1 = OctetString(pqc_pk).dump()
lvl2 = OctetString(lvl1).dump()
encoded_pqc = OctetString(lvl2).dump()

csr = (
    x509.CertificateSigningRequestBuilder()
    .subject_name(
        x509.Name([
            x509.NameAttribute(NameOID.COMMON_NAME, DEVICE_ID),
        ])
    )
    .add_extension(
        x509.UnrecognizedExtension(PQC_OID, encoded_pqc),
        critical=False
    )
    .sign(rsa_key, hashes.SHA256())
)

csr_pem = csr.public_bytes(serialization.Encoding.PEM)

print("CSR built successfully with triple-wrapped PQC extension.")
print(f"PQC Key Length Embedded: {len(pqc_pk)} bytes")

#         ONBOARD MODE

if args.mode == "onboard":

    print("\nCalling onboarding API...")
    resp = requests.post(API_URL, json={"device_id": DEVICE_ID})
    print("API response:", resp.text)

    print(f"\nUploading CSR → s3://{BUCKET}/{CSR_KEY}")
    s3.put_object(Bucket=BUCKET, Key=CSR_KEY, Body=csr_pem)

    print("\nWaiting for certificate issuance...")

    cert_pem = None
    for _ in range(30):
        try:
            obj = s3.get_object(Bucket=BUCKET, Key=CRT_KEY)
            cert_pem = obj["Body"].read().decode()
            print("Certificate retrieved!")
            break
        except Exception:
            time.sleep(1)

    if cert_pem is None:
        raise RuntimeError("Timed out waiting for certificate issuance.")

    with open("device.crt", "w") as f:
        f.write(cert_pem)

    with open("device.key", "wb") as f:
        f.write(
            rsa_key.private_bytes(
                serialization.Encoding.PEM,
                serialization.PrivateFormat.TraditionalOpenSSL,
                serialization.NoEncryption(),
            )
        )

    print("\nONBOARDING COMPLETE!")
    print("Device ID:", DEVICE_ID)
    print("Certificate saved as device.crt")
    print("RSA key saved as device.key")
    exit(0)


#        ATTEST MODE

print("\n========== ATTESTATION ==========\n")
print("Requesting challenge...")

challenge_resp = requests.post(
    ATTEST_URL,
    json={"device_id": DEVICE_ID, "request": "challenge"}
)

print("RAW RESPONSE:", challenge_resp.text)

challenge = challenge_resp.json().get("challenge")
if not challenge:
    raise RuntimeError("Challenge not returned by attestation API.")

print("Challenge:", challenge)

signature = rsa_key.sign(
    challenge.encode(),
    padding.PKCS1v15(),
    hashes.SHA256(),
)

attest_resp = requests.post(
    ATTEST_URL,
    json={
        "device_id": DEVICE_ID,
        "challenge": challenge,
        "signature": signature.hex()
    }
)

print("\nAttestation Result:")
print(attest_resp.json())
print("\nATTESTATION COMPLETE!")
