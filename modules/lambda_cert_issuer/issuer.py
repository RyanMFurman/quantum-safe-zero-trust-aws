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

    # Extract S3 bucket + key from event
    record = event["Records"][0]["s3"]
    bucket = record["bucket"]["name"]
    key = record["object"]["key"]

    print(f"Processing CSR from s3://{bucket}/{key}")

    # Download CSR
    csr_obj = s3.get_object(Bucket=bucket, Key=key)
    csr_body = csr_obj["Body"].read()

    # Submit CSR to PCA
    print("Submitting CSR to ACM-PCA")
    issue_resp = pca.issue_certificate(
        CertificateAuthorityArn=SUB_CA_ARN,
        Csr=csr_body,
        SigningAlgorithm="SHA256WITHRSA",
        Validity={"Value": 365, "Type": "DAYS"}
    )

    cert_arn = issue_resp["CertificateArn"]
    print("CertificateArn:", cert_arn)

    # Poll until certificate is issued
    cert_pem = None
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

    # Create hybrid metadata record (PQC keys were embedded in CSR extension)
    metadata = {
        "certificate_arn": cert_arn,
        "csr_key": key,
        "timestamp": int(time.time())
    }

    # Write certificate + metadata back to S3
    cert_key = key.replace(".csr", ".crt")
    meta_key = key.replace(".csr", ".json")

    s3.put_object(Bucket=bucket, Key=cert_key, Body=cert_pem)
    s3.put_object(Bucket=bucket, Key=meta_key, Body=json.dumps(metadata))

    print(f"Saved certificate as: {cert_key}")
    print(f"Saved metadata as: {meta_key}")

    # Update device registry
    device_id = key.split("/")[-1].replace(".csr", "")

    DEVICE_TABLE.update_item(
        Key={"device_id": device_id},
        UpdateExpression="SET certificate_arn = :c, cert_timestamp = :t",
        ExpressionAttributeValues={
            ":c": cert_arn,
            ":t": int(time.time())
        }
    )

    print(f"Updated DynamoDB for device {device_id}")

    return {
        "status": "ok",
        "certificate_arn": cert_arn,
        "device_id": device_id
    }
