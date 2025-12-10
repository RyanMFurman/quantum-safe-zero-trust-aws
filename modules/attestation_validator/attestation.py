import boto3
import json
import base64
from botocore.exceptions import ClientError
from cryptography.hazmat.primitives import serialization, hashes
from cryptography.hazmat.primitives.asymmetric import padding

dynamodb = boto3.resource("dynamodb")

def lambda_handler(event, context):
    print("Received:", json.dumps(event))

    body = json.loads(event["body"])

    device_id = body["device_id"]
    challenge = base64.b64decode(body["challenge"])
    signature = base64.b64decode(body["signature"])

    table = dynamodb.Table("quantum-safe-device-registry")

    # Fetch stored public key
    resp = table.get_item(Key={"device_id": device_id})
    if "Item" not in resp:
        return {"statusCode": 404, "body": "Device not found"}

    pubkey_pem = resp["Item"]["public_key"]

    public_key = serialization.load_pem_public_key(pubkey_pem.encode("utf-8"))

    # VERIFY RSA SIGNATURE
    try:
        public_key.verify(
            signature,
            challenge,
            padding.PKCS1v15(),
            hashes.SHA256()
        )
    except Exception as e:
        return {"statusCode": 400, "body": f"Invalid signature: {str(e)}"}

    # Update attestation record
    table.update_item(
        Key={"device_id": device_id},
        UpdateExpression="SET attested = :v",
        ExpressionAttributeValues={":v": True}
    )

    return {
        "statusCode": 200,
        "body": json.dumps({"result": "attestation_passed"})
    }
