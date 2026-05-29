import os
import boto3
from datetime import datetime

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(os.environ['DYNAMO_TABLE'])

def lambda_handler(event, context):
    # ISO 8601 formátumú string (pl: "2023-10-27T10:30:00.123456")
    timestamp_str = datetime.now().isoformat()
    
    item = {
        'filename': event['key'],
        'labels': event['labels'],
        'url': event['url'], # Eredeti URL (az S3 kulcs kinyeréséhez kell majd)
        'upload_time': timestamp_str
    }
    
    table.put_item(Item=item)
    return {"status": "success", "item": item}