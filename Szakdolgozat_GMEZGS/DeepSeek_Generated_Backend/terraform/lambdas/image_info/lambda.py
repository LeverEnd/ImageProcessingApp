import json
import boto3
import os
from datetime import datetime

dynamodb = boto3.resource('dynamodb')
s3_client = boto3.client('s3')
DYNAMODB_TABLE = os.environ.get('DYNAMODB_TABLE')
OUTPUT_BUCKET = os.environ.get('OUTPUT_BUCKET')

def lambda_handler(event, context):
    print(f"Received event: {json.dumps(event, indent=2)}")
    
    filename = event.get('filename')
    processed_key = event.get('processed_key')
    upload_time = event.get('upload_time')
    labels = event.get('labels', [])
    
    if not filename:
        raise ValueError("filename is required")
    
    # Csak a label nevek kinyerése string listaként
    label_names = []
    if isinstance(labels, list):
        for label in labels:
            if isinstance(label, dict):
                if 'S' in label:
                    label_names.append(label['S'])
                elif 'name' in label:
                    label_names.append(label['name'])
            elif isinstance(label, str):
                label_names.append(label)
    
    print(f"Label names: {label_names}")
    
    # Generáljuk a kép linkjét
    try:
        url = s3_client.generate_presigned_url(
            'get_object',
            Params={'Bucket': OUTPUT_BUCKET, 'Key': processed_key},
            ExpiresIn=3600
        )
    except Exception as e:
        print(f"Error generating presigned URL: {e}")
        url = f"https://{OUTPUT_BUCKET}.s3.amazonaws.com/{processed_key}"
    
    # Mentés DynamoDB-be
    table = dynamodb.Table(DYNAMODB_TABLE)
    
    item = {
        'filename': filename,
        'labels': label_names,
        'upload_time': upload_time if upload_time else datetime.utcnow().isoformat(),
        'image_url': url,
        'processed_key': processed_key,
        'created_at': datetime.utcnow().isoformat()
    }
    
    table.put_item(Item=item)
    
    return {
        'statusCode': 200,
        'message': 'Metadata saved successfully'
    }