resource "aws_lambda_function" "format_check_lambda" {
  function_name = "format-check-lambda"
  role          = "arn:aws:iam::483288572425:role/LabRole"
  filename      = "${path.module}/Lambda/format_check_lambda.zip"
  handler       = "format_check_lambda.main"
  runtime       = "python3.10"
  timeout       = 30
}

resource "aws_lambda_function" "image_process_and_upload_lambda" {
  function_name = "image-process-and-upload-lambda"
  role          = "arn:aws:iam::483288572425:role/LabRole"
  filename      = "${path.module}/Lambda/image_process_and_upload_lambda.zip"
  handler       = "image_process_and_upload_lambda.main"
  runtime       = "python3.10"
  timeout       = 30
  layers        = ["arn:aws:lambda:us-east-1:770693421928:layer:Klayers-p310-Pillow:14"]
}

resource "aws_lambda_function" "metadata_upload_lambda" {
  function_name = "metadata-upload-lambda"
  role          = "arn:aws:iam::483288572425:role/LabRole"
  filename      = "${path.module}/Lambda/metadata_upload_lambda.zip"
  handler       = "metadata_upload_lambda.main"
  runtime       = "python3.10"
  timeout       = 30
}

resource "aws_lambda_function" "image_get_lambda" {
  function_name = "image-get-lambda"
  role          = "arn:aws:iam::483288572425:role/LabRole"
  filename      = "${path.module}/Lambda/image_get_lambda.zip"
  handler       = "image_get_lambda.main"
  runtime       = "python3.10"
  timeout       = 30
}

resource "aws_lambda_function" "get_presigned_url_lambda" {
  function_name = "get-presigned-url-lambda"
  role          = "arn:aws:iam::483288572425:role/LabRole"
  filename      = "${path.module}/Lambda/get_presigned_url_lambda.zip"
  handler       = "get_presigned_url_lambda.main"
  runtime       = "python3.10"
  timeout       = 30
  environment {
    variables = {
      IN_BUCKET_NAME = aws_s3_bucket.in_bucket_gmezgs.id
    }
  }
}

resource "aws_lambda_function" "image_delete_lambda" {
  function_name = "image-delete-lambda"
  role          = "arn:aws:iam::483288572425:role/LabRole"
  filename      = "${path.module}/Lambda/image_delete_lambda.zip"
  handler       = "image_delete_lambda.main"
  runtime       = "python3.10"
  timeout       = 30
  environment {
    variables = {
      IN_BUCKET_NAME  = aws_s3_bucket.in_bucket_gmezgs.id
      OUT_BUCKET_NAME = aws_s3_bucket.out_bucket_gmezgs.id
    }
  }
}

resource "aws_lambda_function" "rekognition_lambda" {
  function_name = "rekognition-lambda"
  role          = "arn:aws:iam::483288572425:role/LabRole"
  filename      = "${path.module}/Lambda/rekognition_lambda.zip"
  handler       = "rekognition_lambda.main"
  runtime       = "python3.10"
  timeout       = 30
}