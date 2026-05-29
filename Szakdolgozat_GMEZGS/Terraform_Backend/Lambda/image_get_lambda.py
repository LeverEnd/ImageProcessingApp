import boto3
import json

dynamodbResource = boto3.resource("dynamodb")

def main(event, context):
    try:
        table = dynamodbResource.Table("image-metadatas-table-gmezgs")

        response = table.scan()
        items = response.get("Items", [])

        return {
            "statusCode": 200,
            "headers": {
                "Content-Type": "application/json",
                "Access-Control-Allow-Origin": "*" 
            },
            "body": json.dumps(items)
        }

    except Exception as e:
        print(f"Image_get lambda error: {str(e)}")
        return {
            "statusCode": 500,
            "headers": {
                "Content-Type": "application/json",
                "Access-Control-Allow-Origin": "*"
            },
            "body": json.dumps({"error": str(e)})
        }
