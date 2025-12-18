import boto3
import json
import time
import os
from cryptography import x509
from cryptography.hazmat.backends import default_backend
from cryptography.x509.oid import ObjectIdentifier

s3 = boto3.client("s3")
pca = boto3.client("acm-pca")
dynamodb = boto3.resource("dynamodb")

SUB_CA_ARN = os.environ["SUBORDINATE_CA_ARN"]
TABLE_NAME = os.environ["DEVICE_TABLE"]
DEVICE_TABLE = dynamodb.Table(TABLE_NAME)

# Custom OID for your Post-Quantum Cryptography public key extension
PQC_OID = ObjectIdentifier("1.3.6.1.4.1.99999.1.1")


def lambda_handler(event, context):
    print("Received event:", json.dumps(event))

    record = event["Records"][0]["s3"]
    bucket = record["bucket"]["name"]
    key = record["object"]["key"]

    print(f"Processing CSR from s3://{bucket}/{key}")

    csr_body = s3.get_object(Bucket=bucket, Key=key)["Body"].read()

    # Parse CSR and extract PQC extension safely
    pqc_pubkey = None
    try:
        csr = x509.load_pem_x509_csr(csr_body, default_backend())

        # FIXED: Robust extraction of unrecognized (custom) extension
        for ext in csr.extensions:
            if ext.oid == PQC_OID:
                # ext.value is an UnrecognizedExtension instance
                # Its .value attribute contains the raw OCTET STRING bytes
                pqc_pubkey = ext.value.value
                print(f"PQC extension found! Raw length = {len(pqc_pubkey)} bytes")
                break

        if pqc_pubkey is None:
            print("No PQC extension found in CSR")

    except Exception as e:
        print("Failed to parse CSR or process extensions:", str(e))
        raise  # Re-raise to fail the Lambda if CSR is invalid

    # Determine compliance state
    compliance_state = "pqc_ok" if pqc_pubkey else "legacy"
    print(f"Compliance state determined: {compliance_state}")

    # Issue certificate using the subordinate CA
    print("Submitting CSR to ACM PCA...")
    issued = pca.issue_certificate(
        CertificateAuthorityArn=SUB_CA_ARN,
        Csr=csr_body,
        SigningAlgorithm="SHA256WITHRSA",
        Validity={"Value": 365, "Type": "DAYS"},
    )

    cert_arn = issued["CertificateArn"]
    print("Certificate issued, ARN:", cert_arn)

    # Poll for certificate issuance
    cert_pem = None
    chain_pem = None
    for attempt in range(15):
        try:
            resp = pca.get_certificate(
                CertificateAuthorityArn=SUB_CA_ARN,
                CertificateArn=cert_arn
            )
            cert_pem = resp["Certificate"]
            chain_pem = resp["CertificateChain"]
            print("Certificate retrieved successfully")
            break
        except pca.exceptions.RequestInProgressException:
            print(f"Certificate still issuing... attempt {attempt + 1}/15")
            time.sleep(2)
        except Exception as e:
            print("Unexpected error while fetching certificate:", str(e))
            time.sleep(2)

    if cert_pem is None:
        raise Exception("Timed out waiting for certificate to become available")

    # Prepare metadata
    timestamp = int(time.time())
    metadata = {
        "certificate_arn": cert_arn,
        "csr_key": key,
        "timestamp": timestamp,
        "has_pqc": bool(pqc_pubkey),
        "pqc_public_key_length": len(pqc_pubkey) if pqc_pubkey else 0,
        "compliance_state": compliance_state
    }

    # Output filenames
    cert_key = key.replace(".csr", ".crt")
    meta_key = key.replace(".csr", ".json")

    # Store certificate and metadata back to S3
    s3.put_object(Bucket=bucket, Key=cert_key, Body=cert_pem.encode('utf-8'))
    s3.put_object(Bucket=bucket, Key=meta_key, Body=json.dumps(metadata).encode('utf-8'))
    print("Saved certificate and metadata to S3")

    # Extract device ID from object key
    device_id = os.path.basename(key).replace(".csr", "")

    # Update DynamoDB
    DEVICE_TABLE.update_item(
        Key={"device_id": device_id},
        UpdateExpression=(
            "SET certificate_arn = :c, "
            "cert_timestamp = :t, "
            "has_pqc = :p, "
            "pqc_public_key_length = :l, "
            "compliance_state = :s"
        ),
        ExpressionAttributeValues={
            ":c": cert_arn,
            ":t": timestamp,
            ":p": bool(pqc_pubkey),
            ":l": len(pqc_pubkey) if pqc_pubkey else 0,
            ":s": compliance_state,
        }
    )
    print(f"DynamoDB updated for device_id: {device_id} (compliance: {compliance_state})")

    return {
        "status": "ok",
        "device_id": device_id,
        "certificate_arn": cert_arn,
        "has_pqc": bool(pqc_pubkey),
        "compliance_state": compliance_state
    }