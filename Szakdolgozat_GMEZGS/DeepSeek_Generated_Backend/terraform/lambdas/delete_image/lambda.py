import json
import boto3
import os
from urllib.parse import unquote_plus

s3_client = boto3.client('s3')
dynamodb = boto3.resource('dynamodb')

DYNAMODB_TABLE = os.environ.get('DYNAMODB_TABLE')
INPUT_BUCKET = os.environ.get('INPUT_BUCKET')
OUTPUT_BUCKET = os.environ.get('OUTPUT_BUCKET')

def lambda_handler(event, context):
    print(f"Received event: {json.dumps(event)}")
    
    # CORS preflight kezelése
    if event.get('httpMethod') == 'OPTIONS':
        return {
            'statusCode': 200,
            'headers': {
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Methods': 'DELETE, OPTIONS',
                'Access-Control-Allow-Headers': 'Content-Type, X-Amz-Date, Authorization, X-Api-Key, X-Amz-Security-Token'
            },
            'body': ''
        }
    
    filename = None
    if event.get('pathParameters'):
        filename = event['pathParameters'].get('filename')
    
    if not filename:
        return {
            'statusCode': 400,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({'error': 'Filename is required'})
        }
    
    filename = unquote_plus(filename)
    processed_key = f"processed_{filename}"
    
    try:
        # 1. Töröljük a DynamoDB-ből
        table = dynamodb.Table(DYNAMODB_TABLE)
        table.delete_item(Key={'filename': filename})
        print(f"Deleted metadata for {filename} from DynamoDB")
        
        # 2. Töröljük az eredeti képet az input bucket-ből
        try:
            s3_client.delete_object(Bucket=INPUT_BUCKET, Key=filename)
            print(f"Deleted original image: {filename}")
        except Exception as e:
            print(f"Error deleting original image: {e}")
        
        # 3. Töröljük a feldolgozott képet az output bucket-ből
        try:
            s3_client.delete_object(Bucket=OUTPUT_BUCKET, Key=processed_key)
            print(f"Deleted processed image: {processed_key}")
        except Exception as e:
            print(f"Error deleting processed image: {e}")
        
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Methods': 'DELETE, OPTIONS',
                'Access-Control-Allow-Headers': 'Content-Type, X-Amz-Date, Authorization, X-Api-Key, X-Amz-Security-Token'
            },
            'body': json.dumps({
                'message': 'Image and metadata deleted successfully',
                'filename': filename
            })
        }
        
    except Exception as e:
        print(f"Error deleting image: {e}")
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({'error': str(e)})
        }