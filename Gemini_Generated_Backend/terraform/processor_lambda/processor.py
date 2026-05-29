import os
import boto3
from PIL import Image
import io
import time

s3 = boto3.client('s3')
processed_bucket = os.environ['PROCESSED_BUCKET']

def lambda_handler(event, context):
    #time.sleep(12)
    source_bucket = event['bucket']
    key = event['key']
    labels = event['labels']
    
    # Kép letöltése memóriába
    file_byte_string = s3.get_object(Bucket=source_bucket, Key=key)['Body'].read()
    
    # Kép megnyitása
    img = Image.open(io.BytesIO(file_byte_string))
    
    # --- JAVÍTÁS: Átlátszóság kezelése ---
    # Ha a kép RGBA (átlátszó) vagy P (palettás) módú, sima RGB-vé konvertáljuk,
    # mert a JPEG formátum nem tud mit kezdeni az átlátszósággal.
    if img.mode in ("RGBA", "P"):
        img = img.convert("RGB")
    # -------------------------------------
    
    # Átméretezés
    img = img.resize((500, 500), Image.LANCZOS)
    
    # Visszaalakítás byte-okká
    buffer = io.BytesIO()
    img.save(buffer, "JPEG")
    buffer.seek(0)
    
    # Feltöltés a processed bucketbe
    processed_key = f"resized-{key}"
    s3.put_object(Bucket=processed_bucket, Key=processed_key, Body=buffer, ContentType='image/jpeg')
    
    processed_url = f"https://{processed_bucket}.s3.amazonaws.com/{processed_key}"
    
    return {
        "key": key,
        "labels": labels,
        "url": processed_url
    }