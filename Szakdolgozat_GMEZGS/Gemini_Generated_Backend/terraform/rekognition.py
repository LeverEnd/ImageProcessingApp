import boto3

rekognition = boto3.client('rekognition')

def lambda_handler(event, context):
    bucket = event['bucket']
    key = event['key']
    
    response = rekognition.detect_labels(
        Image={'S3Object': {'Bucket': bucket, 'Name': key}},
        MaxLabels=3
    )
    
    labels = [label['Name'] for label in response['Labels']]
    
    return {
        "bucket": bucket,
        "key": key,
        "labels": labels
    }