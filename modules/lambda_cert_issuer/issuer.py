import boto3
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

PQC_OID = x509.ObjectIdentifier("1.3.6.1.4.1.99999.1.1")

def lambda_handler(event, context):
    print("Received event:", json.dumps(event))

    record = event["Records"][0]["s3"]
    bucket = record["bucket"]["name"]
    key = record["object"]["key"]

    print(f"Processing CSR from s3://{bucket}/{key}")

    csr_body = s3.get_object(Bucket=bucket, Key=key)["Body"].read()

    # Parse CSR + PQC extension
    pqc_pubkey = None
    try:
        csr = x509.load_pem_x509_csr(csr_body, default_backend())
        try:
            ext = csr.get_extension_for_oid(PQC_OID)
            pqc_pubkey = ext.value.value
            print(f"PQC pubkey found: {len(pqc_pubkey)} bytes")
        except:
            print("No PQC extension found")
    except Exception as e:
        print("CSR parse failed:", e)

    print("Submitting CSR...")
    issued = pca.issue_certificate(
        CertificateAuthorityArn=SUB_CA_ARN,
        Csr=csr_body,
        SigningAlgorithm="SHA256WITHRSA",
        Validity={"Value": 365, "Type": "DAYS"}
    )

    cert_arn = issued["CertificateArn"]
    print("Cert ARN:", cert_arn)

    # Poll until certificate is ready
    cert_pem = None
    chain_pem = None

    for _ in range(15):
        try:
            resp = pca.get_certificate(
                CertificateAuthorityArn=SUB_CA_ARN,
                CertificateArn=cert_arn
            )
            cert_pem = resp["Certificate"]        # Already PEM TEXT
            chain_pem = resp["CertificateChain"]  # Already PEM TEXT
            break
        except Exception:
            time.sleep(1)

    if cert_pem is None:
        raise Exception("Timed out waiting for certificate")

    print("Certificate ready!")

    timestamp = int(time.time())
    metadata = {
        "certificate_arn": cert_arn,
        "csr_key": key,
        "timestamp": timestamp,
        "has_pqc": bool(pqc_pubkey),
        "pqc_public_key_length": len(pqc_pubkey) if pqc_pubkey else 0
    }

    cert_key = key.replace(".csr", ".crt")
    meta_key = key.replace(".csr", ".json")

    # Store files
    s3.put_object(Bucket=bucket, Key=cert_key, Body=cert_pem.encode())
    s3.put_object(Bucket=bucket, Key=meta_key, Body=json.dumps(metadata).encode())

    print("Saved cert + metadata")

    device_id = key.split("/")[-1].replace(".csr", "")

    DEVICE_TABLE.update_item(
        Key={"device_id": device_id},
        UpdateExpression="SET certificate_arn=:c, cert_timestamp=:t, has_pqc=:p",
        ExpressionAttributeValues={
            ":c": cert_arn,
            ":t": timestamp,
            ":p": bool(pqc_pubkey)
        }
    )

    print("DynamoDB updated for:", device_id)

    return {
        "status": "ok",
        "device_id": device_id,
        "certificate_arn": cert_arn,
        "has_pqc": bool(pqc_pubkey)
    }