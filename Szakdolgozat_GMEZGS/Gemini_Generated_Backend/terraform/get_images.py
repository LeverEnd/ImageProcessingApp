import os
import json
import boto3
from decimal import Decimal

s3 = boto3.client('s3')
dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(os.environ['DYNAMO_TABLE'])
processed_bucket = os.environ['PROCESSED_BUCKET']

class DecimalEncoder(json.JSONEncoder):
    def default(self, obj):
        if isinstance(obj, Decimal):
            return int(obj) if obj % 1 == 0 else float(obj)
        return super(DecimalEncoder, self).default(obj)

def lambda_handler(event, context):
    try:
        response = table.scan()
        items = response.get('Items', [])
        
        for item in items:
            # A DynamoDB-ben tárolt fájlnév alapján generálunk egy 
            # ideiglenes (Presigned) URL-t a feldolgozott képhez.
            # A feldolgozott kép neve: "resized-filename.jpg"
            object_key = f"resized-{item['filename']}"
            
            try:
                presigned_url = s3.generate_presigned_url(
                    'get_object',
                    Params={'Bucket': processed_bucket, 'Key': object_key},
                    ExpiresIn=3600 # 1 óráig érvényes
                )
                # Kicseréljük a statikus URL-t a biztonságos ideiglenesre
                item['url'] = presigned_url
            except Exception:
                item['url'] = "Error generating link"

        return {
            "statusCode": 200,
            "headers": {
                "Content-Type": "application/json",
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Methods": "GET, OPTIONS"
            },
            "body": json.dumps(items, cls=DecimalEncoder)
        }
    except Exception as e:
        return {
            "statusCode": 500,
            "headers": {"Access-Control-Allow-Origin": "*"},
            "body": json.dumps({"error": str(e)})
        }