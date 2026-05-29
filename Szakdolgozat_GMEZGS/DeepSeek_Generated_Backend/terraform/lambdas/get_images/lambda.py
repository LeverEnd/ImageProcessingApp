import json
import boto3
import os
from decimal import Decimal

dynamodb = boto3.resource('dynamodb')
s3_client = boto3.client('s3')
DYNAMODB_TABLE = os.environ.get('DYNAMODB_TABLE')
OUTPUT_BUCKET = os.environ.get('OUTPUT_BUCKET')

class DecimalEncoder(json.JSONEncoder):
    def default(self, obj):
        if isinstance(obj, Decimal):
            return float(obj)
        return super(DecimalEncoder, self).default(obj)

def lambda_handler(event, context):
    print(f"Received event: {json.dumps(event)}")
    
    table = dynamodb.Table(DYNAMODB_TABLE)
    
    try:
        response = table.scan()
        items = response.get('Items', [])
        
        if event.get('queryStringParameters') and event['queryStringParameters'].get('filename'):
            filename = event['queryStringParameters']['filename']
            items = [item for item in items if item['filename'] == filename]
        
        for item in items:
            processed_key = item.get('processed_key')
            if processed_key:
                try:
                    # Presigned URL generálása CORS támogatással
                    presigned_url = s3_client.generate_presigned_url(
                        'get_object',
                        Params={
                            'Bucket': OUTPUT_BUCKET,
                            'Key': processed_key,
                            'ResponseContentType': 'image/jpeg'
                        },
                        ExpiresIn=3600
                    )
                    item['image_url'] = presigned_url
                except Exception as e:
                    print(f"Error generating presigned URL for {processed_key}: {e}")
                    item['image_url'] = None
            else:
                item['image_url'] = None
        
        body = json.dumps(items, cls=DecimalEncoder)
        
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Methods': 'GET, OPTIONS',
                'Access-Control-Allow-Headers': 'Content-Type, X-Amz-Date, Authorization, X-Api-Key, X-Amz-Security-Token'
            },
            'body': body
        }
        
    except Exception as e:
        print(f"Error getting images: {e}")
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Methods': 'GET, OPTIONS',
                'Access-Control-Allow-Headers': 'Content-Type, X-Amz-Date, Authorization, X-Api-Key, X-Amz-Security-Token'
            },
            'body': json.dumps({'error': str(e)})
        }