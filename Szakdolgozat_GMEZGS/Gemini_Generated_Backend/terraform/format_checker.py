import os
import boto3

# Kliensek inicializálása
s3 = boto3.client('s3')
sns = boto3.client('sns')

def lambda_handler(event, context):
    # Adatok kinyerése az EventBridge eseményből
    bucket = event['detail']['bucket']['name']
    key = event['detail']['object']['key']
    
    valid_extensions = ('.jpg', '.jpeg', '.png')
    is_valid = key.lower().endswith(valid_extensions)
    
    if not is_valid:
        # --- ÚJ RÉSZ: Fájl törlése hibás formátum esetén ---
        try:
            s3.delete_object(Bucket=bucket, Key=key)
            deletion_status = " A fájlt automatikusan töröltük az S3-ból."
        except Exception as e:
            deletion_status = f" Hiba történt a törlés során: {str(e)}"
        
        # Értesítés küldése
        sns.publish(
            TopicArn=os.environ['SNS_TOPIC_ARN'],
            Message=(
                f"Hibás formátumú fájl lett feltöltve: {key}.\n"
                f"Csak JPG és PNG engedélyezett.{deletion_status}"
            ),
            Subject="Képfeldolgozó: Érvénytelen fájlformátum"
        )
    
    return {
        "valid": is_valid,
        "bucket": bucket,
        "key": key
    }