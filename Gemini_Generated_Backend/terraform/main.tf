provider "aws" {
  region = "us-east-1" # Learner Lab általában ezt használja
}

# 1. LABROLE LEKÉRÉSE
data "aws_iam_role" "lab_role" {
  name = "LabRole"
}

# 2. VÁLTOZÓK ÉS ALAP ERŐFORRÁSOK
variable "admin_email" {
  default     = "mark.gajdan@gmail.com" # IDE ÍRD A SAJÁT EMAIL CÍMEDET
  description = "SNS értesítésekhez"
}

resource "random_id" "id" {
  byte_length = 4
}

# S3 Bucketek
resource "aws_s3_bucket" "source_bucket" {
  bucket        = "image-upload-source-${random_id.id.hex}"
  force_destroy = true
}

resource "aws_s3_bucket_cors_configuration" "source_bucket_cors" {
  bucket = aws_s3_bucket.source_bucket.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["PUT", "POST", "GET"]
    allowed_origins = ["*"] # Élesben ide a te weboldalad URL-je kerülne
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

resource "aws_s3_bucket_notification" "source_bucket_eb" {
  bucket      = aws_s3_bucket.source_bucket.id
  eventbridge = true # EventBridge integráció bekapcsolása
}

resource "aws_s3_bucket" "processed_bucket" {
  bucket        = "image-processed-${random_id.id.hex}"
  force_destroy = true
}

resource "aws_s3_bucket_cors_configuration" "processed_bucket_cors" {
  bucket = aws_s3_bucket.processed_bucket.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET"]
    allowed_origins = ["*"] # Élesben a weboldalad URL-je
    max_age_seconds = 3000
  }
}

# DynamoDB Tábla
resource "aws_dynamodb_table" "image_db" {
  name           = "ImageMetadata"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "filename"
  attribute {
    name = "filename"
    type = "S"
  }
}

# SNS Topic az emailekhez
resource "aws_sns_topic" "alerts" {
  name = "image-processing-alerts"
}

resource "aws_sns_topic_subscription" "email_sub" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.admin_email
}

# 3. LAMBDA FÜGGVÉNYEK (Dummy zip fájlokat feltételezve, amiket majd frissítesz)
# (A valóságban terraform apply előtt létre kell hozni ezeket a zip fájlokat a lenti python kódokból)

locals {
  lambdas = ["format_checker", "rekognition", "processor", "db_uploader", "get_images", "presigned_url", "delete_image"]
}

resource "aws_lambda_function" "lambdas" {
  for_each         = toset(local.lambdas)
  function_name    = each.key
  role             = data.aws_iam_role.lab_role.arn
  handler          = "${each.key}.lambda_handler"
  runtime          = "python3.9"
  filename         = "${each.key}.zip" # Minden python kódot a saját nevével zip-elj be!
  timeout          = each.key == "processor" ? 30 : 10

  source_code_hash = filebase64sha256("${each.key}.zip")
  
  environment {
    variables = {
      SOURCE_BUCKET    = aws_s3_bucket.source_bucket.bucket
      PROCESSED_BUCKET = aws_s3_bucket.processed_bucket.bucket
      DYNAMO_TABLE     = aws_dynamodb_table.image_db.name
      SNS_TOPIC_ARN    = aws_sns_topic.alerts.arn
    }
  }
}

# 4. CLOUDWATCH ALARM (10 másodperces futásidő riasztás a processzornál)
resource "aws_cloudwatch_metric_alarm" "processor_timeout" {
  alarm_name          = "ProcessorLambdaTimeout"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = "60"
  statistic           = "Maximum"
  threshold           = "10000" # 10,000 ms = 10 másodperc
  alarm_actions       = [aws_sns_topic.alerts.arn]
  dimensions = {
    FunctionName = aws_lambda_function.lambdas["processor"].function_name
  }
}

# 5. STEP FUNCTIONS
resource "aws_sfn_state_machine" "image_pipeline" {
  name     = "ImageProcessingPipeline"
  role_arn = data.aws_iam_role.lab_role.arn

  definition = jsonencode({
    StartAt = "FormatCheck",
    States = {
      FormatCheck = {
        Type = "Task",
        Resource = aws_lambda_function.lambdas["format_checker"].arn,
        Next = "IsFormatValid"
      },
      IsFormatValid = {
        Type = "Choice",
        Choices = [
          { Variable = "$.valid", BooleanEquals = false, Next = "EndPipeline" }
        ],
        Default = "Rekognition"
      },
      Rekognition = {
        Type = "Task",
        Resource = aws_lambda_function.lambdas["rekognition"].arn,
        Next = "ProcessImage"
      },
      ProcessImage = {
        Type = "Task",
        Resource = aws_lambda_function.lambdas["processor"].arn,
        Next = "UploadDB"
      },
      UploadDB = {
        Type = "Task",
        Resource = aws_lambda_function.lambdas["db_uploader"].arn,
        End = true
      },
      EndPipeline = {
        Type = "Pass",
        End = true
      }
    }
  })
}

# 6. EVENTBRIDGE S3 FELTÖLTÉS FIGYELÉSE
resource "aws_cloudwatch_event_rule" "s3_upload" {
  name        = "s3-image-upload-rule"
  description = "Triggers Step Functions on S3 upload"
  event_pattern = jsonencode({
    source      = ["aws.s3"],
    detail-type = ["Object Created"],
    detail = {
      bucket = { name = [aws_s3_bucket.source_bucket.bucket] }
    }
  })
}

resource "aws_cloudwatch_event_target" "step_functions_target" {
  rule     = aws_cloudwatch_event_rule.s3_upload.name
  arn      = aws_sfn_state_machine.image_pipeline.arn
  role_arn = data.aws_iam_role.lab_role.arn
}

# 7. API GATEWAY
resource "aws_apigatewayv2_api" "api" {
  name          = "image-api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["GET", "POST", "PUT", "DELETE", "OPTIONS"]
    allow_headers = ["Content-Type", "Authorization"]
    max_age       = 300
  }
}

resource "aws_apigatewayv2_stage" "prod" {
  api_id      = aws_apigatewayv2_api.api.id
  name        = "prod"
  auto_deploy = true
}

# API Útvonalak (Routes & Integrations)
locals {
  api_routes = {
    "GET /images"           = "get_images"
    "GET /presigned-url"    = "presigned_url"
    "DELETE /images/{name}" = "delete_image"
  }
}

resource "aws_apigatewayv2_integration" "lambda_integrations" {
  for_each               = local.api_routes
  api_id                 = aws_apigatewayv2_api.api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.lambdas[each.value].invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "routes" {
  for_each   = local.api_routes
  api_id     = aws_apigatewayv2_api.api.id
  route_key  = each.key
  target     = "integrations/${aws_apigatewayv2_integration.lambda_integrations[each.key].id}"
}

resource "aws_lambda_permission" "api_gw" {
  for_each      = toset(["get_images", "presigned_url", "delete_image"])
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambdas[each.key].function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.api.execution_arn}/*/*"
}