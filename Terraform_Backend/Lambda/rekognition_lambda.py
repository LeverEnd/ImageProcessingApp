import boto3

rekognitionClient = boto3.client("rekognition")

def main(event, context):
    try:
        in_bucket = event["detail"]["bucket"]["name"]
        key = event["detail"]["object"]["key"]

        response = rekognitionClient.detect_labels(
            Image={
                'S3Object': {
                    'Bucket': in_bucket,
                    'Name': key
                }
            },
            MaxLabels=3,
            MinConfidence=75.0
        )
        
        labels_list = response.get("Labels", [])
        if not labels_list:
            event["labels"] = "Unknown"
            return event
        else:
            label_names = [label["Name"] for label in labels_list]
            event["labels"] = ", ".join(label_names)
            return event
            
    except Exception as e:
        print(f"Rekognition lambda error: {str(e)}")
        event["labels"] = "Rekognition error"
        return event