import os
import json
import boto3

s3 = boto3.client('s3')
dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(os.environ['DYNAMO_TABLE'])
source_bucket = os.environ['SOURCE_BUCKET']
processed_bucket = os.environ['PROCESSED_BUCKET']

def lambda_handler(event, context):
    # Fájlnév kinyerése az URL path-ból (pl. /images/test.jpg)
    filename = event.get('pathParameters', {}).get('name')
    
    if not filename:
        return {"statusCode": 400, "body": "Fájlnév hiányzik."}
    
    try:
        # S3 törlések
        s3.delete_object(Bucket=source_bucket, Key=filename)
        s3.delete_object(Bucket=processed_bucket, Key=f"resized-{filename}")
        
        # DynamoDB törlés
        table.delete_item(Key={'filename': filename})
        
        # Sikeres ág végén:
        return {
            "statusCode": 200, 
            "headers": {"Access-Control-Allow-Origin": "*"},
            "body": json.dumps({"message": f"{filename} sikeresen törölve."})
        }
    except Exception as e:
        # Hiba ág végén:
        return {
            "statusCode": 500, 
            "headers": {"Access-Control-Allow-Origin": "*"},
            "body": str(e)
        }