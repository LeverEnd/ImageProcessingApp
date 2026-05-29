import json
import boto3
import os
from urllib.parse import unquote_plus

sns_client = boto3.client('sns')
s3_client = boto3.client('s3')
SNS_TOPIC_ARN = os.environ.get('SNS_TOPIC_ARN')
ALLOWED_EXTENSIONS = {'.jpg', '.jpeg', '.png'}
ALLOWED_MIME_TYPES = {'image/jpeg', 'image/png'}

def lambda_handler(event, context):
    print(f"=== FORMAT CHECKER STARTED ===")
    print(f"Full event received: {json.dumps(event, indent=2)}")
    
    bucket = None
    key = None
    
    # Különböző formátumok kezelése
    if 'Payload' in event:
        payload = event['Payload']
        if 'detail' in payload:
            bucket = payload['detail'].get('bucket', {}).get('name')
            key = payload['detail'].get('object', {}).get('key')
        else:
            bucket = payload.get('bucket')
            key = payload.get('key')
    elif 'detail' in event:
        bucket = event['detail'].get('bucket', {}).get('name')
        key = event['detail'].get('object', {}).get('key')
    elif 'bucket' in event and 'key' in event:
        bucket = event['bucket']
        key = event['key']
    
    if not bucket or not key:
        print(f"ERROR: Could not extract bucket and key from event: {event}")
        return {
            'isValid': False,
            'error': 'Could not extract bucket and key',
            'bucket': None,
            'key': None
        }
    
    key = unquote_plus(key)
    print(f"Processing file: bucket={bucket}, key={key}")
    
    # Ellenőrizzük a kiterjesztést
    file_extension = '.' + key.split('.')[-1].lower() if '.' in key else ''
    is_valid_extension = file_extension in ALLOWED_EXTENSIONS
    print(f"File extension: {file_extension}, Valid: {is_valid_extension}")
    
    # Ellenőrizzük a MIME típust
    content_type = ''
    is_valid_mime = False
    try:
        head_object = s3_client.head_object(Bucket=bucket, Key=key)
        content_type = head_object.get('ContentType', '')
        is_valid_mime = content_type in ALLOWED_MIME_TYPES
        print(f"Content-Type: {content_type}, Valid: {is_valid_mime}")
    except Exception as e:
        print(f"Error getting object metadata: {e}")
    
    is_valid = is_valid_extension and is_valid_mime
    
    if not is_valid:
        # Rossz formátum esetén küldünk emailt
        message = f"""
Invalid file format detected!

File: {key}
Bucket: {bucket}
Extension: {file_extension}
MIME Type: {content_type}
Timestamp: {context.aws_request_id}

This file was rejected because it is not a valid image format (only .jpg, .jpeg, .png are allowed).
The file has been automatically deleted from S3.
"""
        
        print(f"Sending SNS notification to: {SNS_TOPIC_ARN}")
        try:
            response = sns_client.publish(
                TopicArn=SNS_TOPIC_ARN,
                Subject=f"⚠️ Invalid Format Alert: {key}",
                Message=message
            )
            print(f"SNS sent successfully. MessageId: {response.get('MessageId')}")
        except Exception as e:
            print(f"Error sending SNS notification: {e}")
        
        # TÖRÖLJÜK A NEM KÉPFORMÁTUMÚ FÁJLT AZ S3-BÓL
        try:
            s3_client.delete_object(Bucket=bucket, Key=key)
            print(f"Deleted invalid file: {key} from bucket: {bucket}")
        except Exception as e:
            print(f"Error deleting invalid file from S3: {e}")
    else:
        print(f"Valid image format detected!")
    
    result = {
        'isValid': is_valid,
        'bucket': bucket,
        'key': key
    }
    print(f"Returning: {json.dumps(result)}")
    
    return result