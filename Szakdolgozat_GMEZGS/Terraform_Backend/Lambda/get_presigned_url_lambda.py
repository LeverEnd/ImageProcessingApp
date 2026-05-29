import json
import boto3
import os

s3Client = boto3.client('s3')

def main(event, context):
    try:
        bucket = os.environ['IN_BUCKET_NAME']
        qs = event.get('queryStringParameters') or {}
        fname = qs.get('filename', 'image.png')
        url = s3Client.generate_presigned_url('put_object', Params={'Bucket': bucket, 'Key': fname}, ExpiresIn=300)
        
        return {
            "statusCode": 200,
            "headers": {"Access-Control-Allow-Origin": "*", "Content-Type": "application/json"},
            "body": json.dumps({"uploadURL": url})
        }

    except Exception as e:
        print(f"Get_presigned_url lambda error: {str(e)}")
        return {
            "statusCode": 500,
            "headers": {"Access-Control-Allow-Origin": "*"},
            "body": json.dumps({"error": str(e)})
        }
