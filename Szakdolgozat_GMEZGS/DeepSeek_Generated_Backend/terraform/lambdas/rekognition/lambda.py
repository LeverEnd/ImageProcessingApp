import json
import boto3
from urllib.parse import unquote_plus

rekognition_client = boto3.client('rekognition')

def lambda_handler(event, context):
    print(f"Received event: {json.dumps(event, indent=2)}")
    
    # Különböző event formátumok kezelése
    bucket = None
    key = None
    
    if 'Payload' in event:
        payload = event['Payload']
        bucket = payload.get('bucket')
        key = payload.get('key')
    else:
        bucket = event.get('bucket')
        key = event.get('key')
    
    if not bucket or not key:
        print(f"ERROR: Could not extract bucket and key from event: {event}")
        return {
            'labels': [],
            'bucket': bucket,
            'key': key,
            'error': 'Could not extract bucket and key'
        }
    
    key = unquote_plus(key)
    print(f"Processing Rekognition for: {bucket}/{key}")
    
    try:
        # Rekognition segítségével felismerjük a label-eket
        response = rekognition_client.detect_labels(
            Image={
                'S3Object': {
                    'Bucket': bucket,
                    'Name': key
                }
            },
            MaxLabels=10,
            MinConfidence=70
        )
        
        print(f"Rekognition response: {json.dumps(response, indent=2)}")
        
        # Kiválasszuk a 3 legvalószínűbb label-t
        labels = response.get('Labels', [])
        top_labels = sorted(labels, key=lambda x: x['Confidence'], reverse=True)[:3]
        
        result_labels = [
            {
                'name': label['Name'],
                'confidence': label['Confidence']
            }
            for label in top_labels
        ]
        
        print(f"Top 3 labels: {json.dumps(result_labels, indent=2)}")
        
        return {
            'labels': result_labels,
            'bucket': bucket,
            'key': key
        }
        
    except rekognition_client.exceptions.InvalidImageFormatException as e:
        print(f"Invalid image format for Rekognition: {e}")
        return {
            'labels': [],
            'bucket': bucket,
            'key': key,
            'error': 'Invalid image format for Rekognition'
        }
    except Exception as e:
        print(f"Error in Rekognition: {e}")
        return {
            'labels': [],
            'bucket': bucket,
            'key': key,
            'error': str(e)
        }