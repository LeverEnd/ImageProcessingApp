import json
import boto3
import os
from urllib.parse import unquote_plus
from PIL import Image
import io
import time
from datetime import datetime

s3_client = boto3.client('s3')
OUTPUT_BUCKET = os.environ.get('OUTPUT_BUCKET')

def lambda_handler(event, context):
    # time.sleep(12)
    print(f"Received event: {json.dumps(event)}")
    
    start_time = time.time()
    
    bucket = event['bucket']
    key = unquote_plus(event['key'])
    
    try:
        # Letöltjük a képet az S3-ból
        response = s3_client.get_object(Bucket=bucket, Key=key)
        image_data = response['Body'].read()
        
        # Megnyitjuk a képet PIL-lel
        image = Image.open(io.BytesIO(image_data))
        
        # Átméretezzük 500x500-ra (megtartva az arányokat, majd cropolva)
        image.thumbnail((500, 500), Image.Resampling.LANCZOS)
        
        # Új kép létrehozása 500x500-as fehér háttérrel
        new_image = Image.new('RGB', (500, 500), (255, 255, 255))
        
        # A kép középre helyezése
        x_offset = (500 - image.width) // 2
        y_offset = (500 - image.height) // 2
        new_image.paste(image, (x_offset, y_offset))
        
        # Kép mentése bytes-ba
        output_buffer = io.BytesIO()
        
        # Meghatározzuk a formátumot az eredeti fájl alapján
        file_extension = key.split('.')[-1].lower()
        if file_extension in ['jpg', 'jpeg']:
            output_format = 'JPEG'
            mime_type = 'image/jpeg'
        else:
            output_format = 'PNG'
            mime_type = 'image/png'
        
        new_image.save(output_buffer, format=output_format)
        output_buffer.seek(0)
        
        # Feltöltjük a feldolgozott képet az output bucket-be
        output_key = f"processed_{key}"
        s3_client.put_object(
            Bucket=OUTPUT_BUCKET,
            Key=output_key,
            Body=output_buffer,
            ContentType=mime_type
        )
        
        upload_time = datetime.utcnow().isoformat()
        processing_time = time.time() - start_time
        
        print(f"Image processed successfully. Output key: {output_key}, Processing time: {processing_time:.2f}s")
        
        return {
            'processed_key': output_key,
            'upload_time': upload_time,
            'processing_time': processing_time,
            'bucket': bucket,
            'original_key': key
        }
        
    except Exception as e:
        print(f"Error processing image: {e}")
        raise e