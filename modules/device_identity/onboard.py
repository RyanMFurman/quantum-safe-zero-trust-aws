import json
import boto3
import os
import traceback

dynamodb = boto3.client("dynamodb")

DEVICE_TABLE = os.environ.get("DEVICE_TABLE")
SUB_CA_ARN   = os.environ.get("SUB_CA_ARN")

def handler(event, context):
    print("EVENT:", json.dumps(event))

    try:
        # Parse body from API Gateway
        body = json.loads(event.get("body", "{}"))
        device_id = body.get("device_id")

        if not device_id:
            return _response(400, {"error": "device_id missing"})

        # Attempt DynamoDB write
        print(f"Writing device record for {device_id} to table {DEVICE_TABLE}")
        dynamodb.put_item(
            TableName=DEVICE_TABLE,
            Item={"device_id": {"S": device_id}}
        )

        return _response(200, {
            "message": "Device onboarded successfully",
            "device_id": device_id,
            "sub_ca_used": SUB_CA_ARN
        })

    except Exception as e:
        print("ERROR:", str(e))
        print(traceback.format_exc())
        return _response(500, {"error": "Server error", "detail": str(e)})

def _response(code, body):
    return {
        "statusCode": code,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(body)
    }
