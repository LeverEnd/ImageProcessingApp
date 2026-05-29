import boto3
import io
from PIL import Image
import time

s3Client = boto3.client("s3")

def main(event, context):
    try:
        #time.sleep(12)
        in_bucket = event["detail"]["bucket"]["name"]
        key = event["detail"]["object"]["key"]

        out_bucket = "out-bucket-gmezgs"
        new_key = f"resized_{key}"

        response = s3Client.get_object(Bucket=in_bucket, Key=key)
        img_data = response["Body"].read()

        image = Image.open(io.BytesIO(img_data))
        resized_img = image.resize((500, 500)) 

        buffer = io.BytesIO()
        resized_img.save(buffer, format=image.format)
        
        buffer.seek(0)

        s3Client.put_object(
            Bucket=out_bucket,
            Key=new_key,
            Body=buffer,
            ContentType=f"image/{image.format}"
        )

        event["processed"] = {
            "bucket": out_bucket,
            "key": new_key
        }

        return event

    except Exception as e:
        print(f"Image_process_and_upload lambda error: {str(e)}")
        raise e
