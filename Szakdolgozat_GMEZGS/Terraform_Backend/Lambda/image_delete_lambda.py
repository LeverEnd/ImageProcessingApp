import boto3
import os
import json

s3Client = boto3.client("s3")
dynamodbResource = boto3.resource("dynamodb")

def main(event, context):
    try:
        qs = event.get("queryStringParameters") or {}
        out_filename = qs.get("filename")
        in_filename = out_filename.replace("resized_", "", 1)

        in_bucket = os.environ["IN_BUCKET_NAME"]
        out_bucket = os.environ["OUT_BUCKET_NAME"]
        table_name = "image-metadatas-table-gmezgs"

        s3Client.delete_object(Bucket=in_bucket, Key=in_filename)
        s3Client.delete_object(Bucket=out_bucket, Key=out_filename)
        table = dynamodbResource.Table(table_name)
        table.delete_item(Key={"FileName": out_filename})

        return {
            "statusCode": 200,
            "headers": {"Access-Control-Allow-Origin": "*"},
            "body": json.dumps({"message": "Delete successful!"})
        }

    except Exception as e:
        print(f"Image_delete lambda error: {str(e)}")
        return {
            "statusCode": 500,
            "headers": {"Access-Control-Allow-Origin": "*"},
            "body": json.dumps({"message": "Delete failed!"})
        }
