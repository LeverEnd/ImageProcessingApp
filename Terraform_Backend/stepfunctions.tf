resource "aws_sfn_state_machine" "sfn_for_lambdas" {
  name     = "sfn-for-lambdas"
  role_arn = "arn:aws:iam::483288572425:role/LabRole"

  definition = <<EOF
{
    "Comment": "A sfn to control the lambdas for image processing",
    "StartAt": "FormatCheck",
    "States": {
        "FormatCheck": {
            "Type": "Task",
            "Resource": "${aws_lambda_function.format_check_lambda.arn}",
            "Next": "Rekognition"
        },
        "Rekognition": {
            "Type": "Task",
            "Resource": "${aws_lambda_function.rekognition_lambda.arn}",
            "Next": "ImageProcessAndUpload"
        },
        "ImageProcessAndUpload": {
            "Type": "Task",
            "Resource": "${aws_lambda_function.image_process_and_upload_lambda.arn}",
            "Next": "MetadataUpload"
        },
        "MetadataUpload": {
            "Type": "Task",
            "Resource": "${aws_lambda_function.metadata_upload_lambda.arn}",
            "End": true
        }
    }
}
EOF
}

resource "aws_cloudwatch_event_target" "s3" {
  rule      = aws_cloudwatch_event_rule.console.name
  target_id = "TriggerStepFunctions"
  arn       = aws_sfn_state_machine.sfn_for_lambdas.arn
  role_arn  = "arn:aws:iam::483288572425:role/LabRole"
}