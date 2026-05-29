import boto3

s3Client = boto3.client("s3")
snsClient = boto3.client("sns")

def main(event, context):
    try:
        in_bucket = event["detail"]["bucket"]["name"]
        key = event["detail"]["object"]["key"]

        if key.lower().endswith((".png", ".jpg", ".jpeg")):
            return event
        else:
            snsClient.publish(
                TopicArn = "arn:aws:sns:us-east-1:483288572425:upload-error-message",
                Subject = "Nem megfelelő fájl került feltöltésre",
                Message = "Hibás formátum! Csak .png, .jpg, és .jpeg fájlok az elfogadottak."
            )

            s3Client.delete_object(
                Bucket=in_bucket,
                Key=key
            )

            raise Exception("Hibás formátum")
    
    except Exception as e:
        print(f"Format_check lambda error: {str(e)}")
        raise e