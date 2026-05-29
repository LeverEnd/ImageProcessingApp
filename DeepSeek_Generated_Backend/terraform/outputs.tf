output "api_gateway_url" {
  description = "API Gateway URL"
  value       = "${aws_api_gateway_stage.prod.invoke_url}/images"
}

output "input_bucket_name" {
  description = "Input S3 bucket name"
  value       = aws_s3_bucket.input_bucket.id
}

output "output_bucket_name" {
  description = "Output S3 bucket name"
  value       = aws_s3_bucket.output_bucket.id
}

output "dynamodb_table_name" {
  description = "DynamoDB table name"
  value       = aws_dynamodb_table.image_metadata.name
}

output "state_machine_arn" {
  description = "Step Functions state machine ARN"
  value       = aws_sfn_state_machine.image_processing.arn
}