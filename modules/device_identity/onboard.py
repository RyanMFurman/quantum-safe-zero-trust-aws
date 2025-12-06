import boto3
import json
import base64
import os
from datetime import datetime

dynamodb = boto3.resource("dynamodb")
pca = boto3.client("acm-pca")

TABLE_NAME = os.environ["DEVICE_TABLE"]
SUB_CA_ARN = os.environ["SUB_CA_ARN"]

def handler(event, context):
    body = json.loads(event["body"])

    device_id = body["device_id"]
    csr_b64 = body["csr"]  # CSR from device

    csr_bytes = base64.b64decode(csr_b64)

    # Issue cert
    cert_arn = pca.issue_certificate(
        CertificateAuthorityArn=SUB_CA_ARN,
        Csr=csr_bytes,
        SigningAlgorithm="SHA256WITHRSA",
        Validity={"Value": 365, "Type": "DAYS"},
        IdempotencyToken=device_id
    )["CertificateArn"]

    cert = pca.get_certificate(
        CertificateAuthorityArn=SUB_CA_ARN,
        CertificateArn=cert_arn
    )

    # Store device in DynamoDB
    table = dynamodb.Table(TABLE_NAME)
    table.put_item(
        Item={
            "device_id": device_id,
            "registered_at": datetime.utcnow().isoformat(),
            "cert_arn": cert_arn
        }
    )

    return {
        "statusCode": 200,
        "body": json.dumps({
            "certificate": cert["Certificate"],
            "certificate_chain": cert["CertificateChain"]
        })
    }
