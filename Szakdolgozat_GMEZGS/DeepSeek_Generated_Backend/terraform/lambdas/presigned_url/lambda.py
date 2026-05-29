import json
import boto3
import os
import uuid
import mimetypes

s3_client = boto3.client('s3')
INPUT_BUCKET = os.environ.get('INPUT_BUCKET')

def lambda_handler(event, context):
    print(f"Received event: {json.dumps(event)}")
    
    if event.get('httpMethod') == 'OPTIONS':
        return {
            'statusCode': 200,
            'headers': {
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Methods': 'GET, PUT, OPTIONS',
                'Access-Control-Allow-Headers': 'Content-Type, X-Amz-Date, Authorization, X-Api-Key, X-Amz-Security-Token'
            },
            'body': ''
        }
    
    try:
        filename = None
        if event.get('queryStringParameters'):
            filename = event['queryStringParameters'].get('filename')
        
        if not filename:
            filename = f"upload_{uuid.uuid4().hex}.jpg"
        
        # Kiterjesztés alapján MIME típus meghatározása
        content_type, encoding = mimetypes.guess_type(filename)
        if not content_type:
            content_type = 'image/jpeg'  # alapértelmezett
        
        print(f"Filename: {filename}, Content-Type: {content_type}")
        
        # Presigned URL generálása a helyes ContentType-dal
        presigned_url = s3_client.generate_presigned_url(
            'put_object',
            Params={
                'Bucket': INPUT_BUCKET,
                'Key': filename,
                'ContentType': content_type
            },
            ExpiresIn=300
        )
        
        print(f"Generated presigned URL for: {filename}")
        
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Methods': 'GET, PUT, OPTIONS',
                'Access-Control-Allow-Headers': 'Content-Type, X-Amz-Date, Authorization, X-Api-Key, X-Amz-Security-Token'
            },
            'body': json.dumps({
                'upload_url': presigned_url,
                'filename': filename,
                'bucket': INPUT_BUCKET,
                'content_type': content_type
            })
        }
        
    except Exception as e:
        print(f"Error generating presigned URL: {e}")
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({'error': str(e)})
        }