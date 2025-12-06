import boto3
import os

kms = boto3.client("kms")
s3 = boto3.client("s3")

def handler(event, context):
    print("Received S3 event:", event)

    record = event["Records"][0]
    bucket = record["s3"]["bucket"]["name"]
    key    = record["s3"]["object"]["key"]

    # Download file
    download_path = f"/tmp/{key.split('/')[-1]}"
    s3.download_file(bucket, key, download_path)

    # "Scan" placeholder
    scan_result = f"File {key} scanned successfully."

    # Encrypt the scan result with PQC hybrid key
    kms_key_arn = os.environ["KMS_KEY_ARN"]
    
    encrypted = kms.encrypt(
        KeyId=kms_key_arn,
        Plaintext=scan_result.encode(),
    )["CiphertextBlob"]

    # Upload encrypted result
    result_key = key + ".scan.enc"

    s3.put_object(
        Bucket=bucket,
        Key=result_key,
        Body=encrypted,
    )

    return {"status": "ok", "result_key": result_key}
