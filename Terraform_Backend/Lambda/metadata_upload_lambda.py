import boto3

dynamodbResource = boto3.resource("dynamodb")

def main(event, context):
    try:
        bucket = event["processed"]["bucket"]
        key = event["processed"]["key"]
        labels = event["labels"]

        date = event["time"]
        link = f"https://{bucket}.s3.amazonaws.com/{key}"
        table = dynamodbResource.Table("image-metadatas-table-gmezgs")

        table.put_item(
            Item={
                "FileName": f"{key}",
                "Labels": labels,
                "Date": date,
                "Link": link
            }
        )
        
        return event

    except Exception as e:
        print(f"Metadata_upload lambda error: {str(e)}")
        raise e
