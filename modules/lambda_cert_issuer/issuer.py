import boto3
import base64
import json
import time
import os
from cryptography import x509
from cryptography.hazmat.backends import default_backend

s3 = boto3.client("s3")
pca = boto3.client("acm-pca")
dynamodb = boto3.resource("dynamodb")

SUB_CA_ARN = os.environ["SUBORDINATE_CA_ARN"]
TABLE_NAME = os.environ["DEVICE_TABLE"]
DEVICE_TABLE = dynamodb.Table(TABLE_NAME)

# OID for PQC extension (device-side embeds Kyber pubkey here)
PQC_OID = x509.ObjectIdentifier("2.5.29.99")

def lambda_handler(event, context):
    print("Received event:", json.dumps(event))

    record = event["Records"][0]["s3"]
    bucket = record["bucket"]["name"]
    key = record["object"]["key"]

    print(f"Processing CSR from s3://{bucket}/{key}")

    # --- 1. Download CSR ---
    csr_obj = s3.get_object(Bucket=bucket, Key=key)
    csr_body = csr_obj["Body"].read()

    # Parse CSR to extract PQC extension if present
    try:
        csr = x509.load_pem_x509_csr(csr_body, default_backend())
        try:
            ext = csr.get_extension_for_oid(PQC_OID)
            pqc_pubkey = ext.value.value  # raw PQC public key bytes
            print(f"PQC public key extracted ({len(pqc_pubkey)} bytes)")
        except Exception:
            pqc_pubkey = None
            print("No PQC public key found in CSR")
    except Exception as e:
        print("CSR parsing failed:", e)
        pqc_pubkey = None

    # --- 2. Submit CSR to ACM-PCA ---
    print("Submitting CSR to ACM-PCA")
    issue_resp = pca.issue_certificate(
        CertificateAuthorityArn=SUB_CA_ARN,
        Csr=csr_body,
        SigningAlgorithm="SHA256WITHRSA",
        Validity={"Value": 365, "Type": "DAYS"}
    )

    cert_arn = issue_resp["CertificateArn"]
    print("CertificateArn:", cert_arn)

    # --- 3. Poll until certificate is issued ---
    cert_pem = None
    chain_pem = None

    for _ in range(10):
        try:
            get_resp = pca.get_certificate(
                CertificateAuthorityArn=SUB_CA_ARN,
                CertificateArn=cert_arn
            )
            cert_pem = get_resp["Certificate"]
            chain_pem = get_resp["CertificateChain"]
            break
        except Exception:
            time.sleep(2)

    if cert_pem is None:
        raise Exception("Timed out waiting for certificate")

    print("Certificate issued successfully")

    # --- 4. Prepare metadata ---
    timestamp = int(time.time())

    metadata = {
        "certificate_arn": cert_arn,
        "csr_key": key,
        "timestamp": timestamp,
        "pqc_public_key_length": len(pqc_pubkey) if pqc_pubkey else 0,
        "has_pqc": bool(pqc_pubkey)
    }

    cert_key = key.replace(".csr", ".crt")
    meta_key = key.replace(".csr", ".json")

    # --- 5. Store certificate + metadata in S3 ---
    s3.put_object(Bucket=bucket, Key=cert_key, Body=cert_pem)
    s3.put_object(Bucket=bucket, Key=meta_key, Body=json.dumps(metadata))

    print(f"Saved certificate at: {cert_key}")
    print(f"Saved metadata at: {meta_key}")

    # --- 6. Update DynamoDB ---
    device_id = key.split("/")[-1].replace(".csr", "")

    DEVICE_TABLE.update_item(
        Key={"device_id": device_id},
        UpdateExpression="SET certificate_arn = :c, cert_timestamp = :t, has_pqc = :p",
        ExpressionAttributeValues={
            ":c": cert_arn,
            ":t": timestamp,
            ":p": bool(pqc_pubkey)
        }
    )

    print(f"Updated DynamoDB for device {device_id}")

    return {
        "status": "ok",
        "certificate_arn": cert_arn,
        "device_id": device_id,
        "pqc": bool(pqc_pubkey)
    }
