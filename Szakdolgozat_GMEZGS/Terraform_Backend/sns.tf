resource "aws_sns_topic" "upload_error_message" {
  name = "upload-error-message"
}

resource "aws_sns_topic_subscription" "upload_error_subscription" {
  topic_arn = aws_sns_topic.upload_error_message.arn
  protocol  = "email"
  endpoint  = "mark.gajdan@gmail.com"
}

resource "aws_cloudwatch_metric_alarm" "image_upload_fail_alarm" {
  alarm_name          = "image-upload-fail-alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  threshold           = 10000
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  statistic           = "Maximum"
  period              = 60
  alarm_actions       = [aws_sns_topic.upload_error_message.arn]
  dimensions = {
    FunctionName = aws_lambda_function.image_process_and_upload_lambda.function_name
  }
}