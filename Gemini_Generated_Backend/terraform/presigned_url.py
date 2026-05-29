import os
import json
import boto3

s3 = boto3.client('s3')
bucket_name = os.environ['SOURCE_BUCKET']

def lambda_handler(event, context):
    # A fájlnevet a query stringből kérjük el (pl. /presigned-url?filename=test.jpg)
    filename = event.get('queryStringParameters', {}).get('filename', 'upload.jpg')
    
    presigned_url = s3.generate_presigned_url(
        'put_object',
        Params={'Bucket': bucket_name, 'Key': filename},
        ExpiresIn=3600
    )
    
    return {
        "statusCode": 200,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*" # CORS kiegészítés
        },
        "body": json.dumps({"upload_url": presigned_url, "filename": filename})
    }