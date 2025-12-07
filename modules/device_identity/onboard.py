import json
import boto3
import os

dynamodb = boto3.client("dynamodb")

DEVICE_TABLE = os.environ.get("DEVICE_TABLE")
SUB_CA_ARN   = os.environ.get("SUB_CA_ARN")

def handler(event, context):
    print("Received event:", json.dumps(event))

    # --- Parse API Gateway payload ---
    if "body" in event:
        try:
            body = json.loads(event["body"])
        except Exception:
            return {
                "statusCode": 400,
                "body": json.dumps({"error": "Invalid JSON body"})
            }
    else:
        # Direct Lambda invoke (CLI)
        body = event

    device_id = body.get("device_id")
    if not device_id:
        return {
            "statusCode": 400,
            "body": json.dumps({"error": "device_id missing"})
        }

    # --- Write device record ---
    dynamodb.put_item(
        TableName=DEVICE_TABLE,
        Item={"device_id": {"S": device_id}}
    )

    return {
        "statusCode": 200,
        "headers": {
            "Content-Type": "application/json"
        },
        "body": json.dumps({
            "message": "Device onboarded successfully",
            "device_id": device_id,
            "sub_ca_used": SUB_CA_ARN
        })
    }
