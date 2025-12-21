import json
import boto3
import base64
import os
import time
from cryptography import x509
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.asymmetric import padding

DDB = boto3.resource("dynamodb")
TABLE = DDB.Table(os.environ["DEVICE_TABLE"])
S3 = boto3.client("s3")

BUCKET = "quantum-safe-artifacts-dev"

def lambda_handler(event, context):

    # -------- FIX #1: Parse body safely --------
    try:
        body = json.loads(event.get("body", "{}"))
    except:
        return respond(400, {"error": "Invalid request format"})

    if "device_id" not in body:
        return respond(400, {"error": "Missing device_id"})

    device_id = body["device_id"]

    # -------- HANDLE CHALLENGE REQUEST --------
    if body.get("request") == "challenge":
        challenge = f"attest-{device_id}-{int(time.time())}"
        return respond(200, {"challenge": challenge})


    # -------- SIGNATURE VERIFICATION --------
    if "challenge" not in body or "signature" not in body:
        return respond(400, {"error": "Missing challenge or signature"})

    challenge = body["challenge"]
    signature = bytes.fromhex(body["signature"])

    crt_key = f"csr/{device_id}.crt"

    # -------- FIX #2: Load certificate from S3 --------
    try:
        cert_obj = S3.get_object(Bucket=BUCKET, Key=crt_key)
        cert_pem = cert_obj["Body"].read().decode()
        cert = x509.load_pem_x509_certificate(cert_pem.encode())
    except Exception as e:
        return respond(400, {
            "error": "Device certificate not found",
            "detail": str(e)
        })

    pub = cert.public_key()

    # -------- VERIFY RSA SIGNATURE --------
    try:
        pub.verify(
            signature,
            challenge.encode(),
            padding.PKCS1v15(),
            hashes.SHA256()
        )
    except Exception as e:
        return respond(400, {"error": "Signature verification failed", "detail": str(e)})

    # -------- FIX #3: Validate that the cert exists in DynamoDB --------
    # -------- STEP 3: Enforce PQC compliance --------
    try:
        item = TABLE.get_item(Key={"device_id": device_id}).get("Item", None)
        
        if not item:
            return respond(400, {"error": "Device not registered"})
        
        # STEP 3: Check PQC compliance
        if not item.get("has_pqc", False):
            return respond(400, {
                "error": "Device is NOT PQC compliant",
                "compliance_state": item.get("compliance_state", "legacy")
            })
            
    except Exception as e:
        return respond(400, {"error": "DynamoDB read failed", "detail": str(e)})

    # -------- UPDATE DEVICE STATUS --------
    TABLE.update_item(
        Key={"device_id": device_id},
        UpdateExpression="SET last_attested=:t, attestation_status=:s",
        ExpressionAttributeValues={
            ":t": int(time.time()),
            ":s": "verified"
        }
    )

    return respond(200, {
        "message": "Attestation successful",
        "device": device_id,
        "compliance_state": item.get("compliance_state", "pqc_ok")
    })


def respond(code, body):
    return {
        "statusCode": code,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(body)
    }