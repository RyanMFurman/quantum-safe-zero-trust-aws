import boto3
import base64
import json
import time
import os

s3 = boto3.client("s3")
pca = boto3.client("acm-pca")
dynamodb = boto3.resource("dynamodb")

SUB_CA_ARN = os.environ["SUBORDINATE_CA_ARN"]
TABLE_NAME = os.environ["DEVICE_TABLE"]
DEVICE_TABLE = dynamodb.Table(TABLE_NAME)

def lambda_handler(event, context):
    print("Received event:", json.dumps(event))

    record = event["Records"][0]["s3"]
    bucket = record["bucket"]["name"]
    key = record["object"]["key"]

    print(f"Processing CSR from s3://{bucket}/{key}")

    # --- 1. Download CSR ---
    csr_obj = s3.get_object(Bucket=bucket, Key=key)
    csr_body = csr_obj["Body"].read()

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
    expires_at = timestamp + (365 * 24 * 3600)

    cert_key = key.replace(".csr", ".crt")
    meta
