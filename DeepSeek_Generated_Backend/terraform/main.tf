terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Random suffix a globálisan egyedi bucket nevekhez
resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

# S3 bucket az eredeti képeknek
resource "aws_s3_bucket" "input_bucket" {
  bucket = "image-input-${random_string.suffix.result}"
}

resource "aws_s3_bucket_versioning" "input_bucket_versioning" {
  bucket = aws_s3_bucket.input_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "input_bucket_block" {
  bucket = aws_s3_bucket.input_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# AZ S3 BUCKET EVENTBRIDGE ENGEDÉLYEZÉSE - EZ A HELYES MÓDSZER
resource "aws_s3_bucket_notification" "input_bucket_notification" {
  bucket = aws_s3_bucket.input_bucket.id
  
  # EventBridge engedélyezése - ez a helyes szintaxis
  eventbridge = true
  
  # VAGY használhatod a queue, topic, lambda configuration-ök nélkül
  # Csak az eventbridge = true elég
}

# S3 bucket policy az input bucket-hoz - PUT művelet engedélyezése
resource "aws_s3_bucket_policy" "input_bucket_policy" {
  bucket = aws_s3_bucket.input_bucket.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = data.aws_iam_role.lab_role.arn
        }
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject"
        ]
        Resource = "${aws_s3_bucket.input_bucket.arn}/*"
      }
    ]
  })
}

# CORS konfiguráció az input bucket-hez (ha közvetlen S3 feltöltés van)
resource "aws_s3_bucket_cors_configuration" "input_bucket_cors" {
  bucket = aws_s3_bucket.input_bucket.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["PUT", "POST", "GET", "HEAD"]
    allowed_origins = ["*"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

# S3 bucket a feldolgozott (500x500) képeknek - CORS beállításokkal
resource "aws_s3_bucket" "output_bucket" {
  bucket = "image-output-${random_string.suffix.result}"
}

resource "aws_s3_bucket_versioning" "output_bucket_versioning" {
  bucket = aws_s3_bucket.output_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "output_bucket_block" {
  bucket = aws_s3_bucket.output_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# CORS konfiguráció az output bucket-hez - EZ A HIÁNYZÓ RÉSZ
resource "aws_s3_bucket_cors_configuration" "output_bucket_cors" {
  bucket = aws_s3_bucket.output_bucket.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "HEAD"]
    allowed_origins = ["*"]  # Productionben cseréld a specifikus domainre
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

# Current identity az account ID lekéréséhez
data "aws_caller_identity" "current" {}

# DynamoDB tábla
resource "aws_dynamodb_table" "image_metadata" {
  name         = "image-metadata-${random_string.suffix.result}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "filename"

  attribute {
    name = "filename"
    type = "S"
  }

  tags = {
    Name        = "image-metadata"
    Environment = var.environment
  }
}

# SNS témák
resource "aws_sns_topic" "invalid_format_topic" {
  name = "invalid-format-topic-${random_string.suffix.result}"
}

resource "aws_sns_topic" "lambda_timeout_topic" {
  name = "lambda-timeout-topic-${random_string.suffix.result}"
}

# Email subscription-ök (az email címet változóban kell megadni)
resource "aws_sns_topic_subscription" "invalid_format_email" {
  topic_arn = aws_sns_topic.invalid_format_topic.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_sns_topic_subscription" "lambda_timeout_email" {
  topic_arn = aws_sns_topic.lambda_timeout_topic.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# LabRole használata - Learner Lab előre definiált role-ja
data "aws_iam_role" "lab_role" {
  name = "LabRole"
}

# Lambda függvények a LabRole használatával
resource "aws_lambda_function" "format_checker" {
  filename         = data.archive_file.format_checker.output_path
  source_code_hash = data.archive_file.format_checker.output_base64sha256
  function_name    = "format-checker-${random_string.suffix.result}"
  role             = data.aws_iam_role.lab_role.arn
  handler          = "lambda.lambda_handler"
  runtime          = "python3.12"
  timeout          = 10
  memory_size      = 128

  environment {
    variables = {
      SNS_TOPIC_ARN = aws_sns_topic.invalid_format_topic.arn
    }
  }
}

resource "aws_lambda_function" "rekognition" {
  filename         = data.archive_file.rekognition.output_path
  source_code_hash = data.archive_file.rekognition.output_base64sha256
  function_name    = "rekognition-${random_string.suffix.result}"
  role             = data.aws_iam_role.lab_role.arn
  handler          = "lambda.lambda_handler"
  runtime          = "python3.12"
  timeout          = 30
  memory_size      = 256
}

# Hozz létre egy Lambda Layer-t a Pillow számára
resource "aws_lambda_layer_version" "pillow_layer" {
  filename         = data.archive_file.pillow_layer.output_path
  source_code_hash = data.archive_file.pillow_layer.output_base64sha256
  layer_name       = "pillow-layer-${random_string.suffix.result}"
  compatible_runtimes = ["python3.12"]
  description      = "Pillow library for image processing"
}

# Töltsd fel a Pillow layer-t
data "archive_file" "pillow_layer" {
  type        = "zip"
  source_dir  = "${path.module}/pillow_layer"
  output_path = "/tmp/pillow_layer.zip"
}

# Módosított image_processor lambda layer használatával
resource "aws_lambda_function" "image_processor" {
  filename         = data.archive_file.image_processor.output_path
  source_code_hash = data.archive_file.image_processor.output_base64sha256
  function_name    = "image-processor-${random_string.suffix.result}"
  role             = data.aws_iam_role.lab_role.arn
  handler          = "lambda.lambda_handler"
  runtime          = "python3.12"
  timeout          = 30
  memory_size      = 512
  layers           = [aws_lambda_layer_version.pillow_layer.arn]

  environment {
    variables = {
      OUTPUT_BUCKET = aws_s3_bucket.output_bucket.id
    }
  }
}

resource "aws_lambda_function" "image_info" {
  filename         = data.archive_file.image_info.output_path
  source_code_hash = data.archive_file.image_info.output_base64sha256
  function_name    = "image-info-${random_string.suffix.result}"
  role             = data.aws_iam_role.lab_role.arn
  handler          = "lambda.lambda_handler"
  runtime          = "python3.12"
  timeout          = 10
  memory_size      = 128

  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.image_metadata.name
      OUTPUT_BUCKET  = aws_s3_bucket.output_bucket.id
    }
  }
}

resource "aws_lambda_function" "get_images" {
  filename         = data.archive_file.get_images.output_path
  source_code_hash = data.archive_file.get_images.output_base64sha256
  function_name    = "get-images-${random_string.suffix.result}"
  role             = data.aws_iam_role.lab_role.arn
  handler          = "lambda.lambda_handler"
  runtime          = "python3.12"
  timeout          = 10
  memory_size      = 128

  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.image_metadata.name
      OUTPUT_BUCKET  = aws_s3_bucket.output_bucket.id  # EZT ADD HOZZÁ
    }
  }
}

resource "aws_lambda_function" "presigned_url" {
  filename         = data.archive_file.presigned_url.output_path
  source_code_hash = data.archive_file.presigned_url.output_base64sha256
  function_name    = "presigned-url-${random_string.suffix.result}"
  role             = data.aws_iam_role.lab_role.arn
  handler          = "lambda.lambda_handler"
  runtime          = "python3.12"
  timeout          = 10
  memory_size      = 128

  environment {
    variables = {
      INPUT_BUCKET = aws_s3_bucket.input_bucket.id
    }
  }
}

resource "aws_lambda_function" "delete_image" {
  filename         = data.archive_file.delete_image.output_path
  source_code_hash = data.archive_file.delete_image.output_base64sha256
  function_name    = "delete-image-${random_string.suffix.result}"
  role             = data.aws_iam_role.lab_role.arn
  handler          = "lambda.lambda_handler"
  runtime          = "python3.12"
  timeout          = 30
  memory_size      = 256

  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.image_metadata.name
      INPUT_BUCKET   = aws_s3_bucket.input_bucket.id
      OUTPUT_BUCKET  = aws_s3_bucket.output_bucket.id
    }
  }
}

# Lambda kódok tömörítése
data "archive_file" "format_checker" {
  type        = "zip"
  source_dir  = "${path.module}/lambdas/format_checker"
  output_path = "/tmp/format_checker.zip"
}

data "archive_file" "rekognition" {
  type        = "zip"
  source_dir  = "${path.module}/lambdas/rekognition"
  output_path = "/tmp/rekognition.zip"
}

data "archive_file" "image_processor" {
  type        = "zip"
  source_dir  = "${path.module}/lambdas/image_processor"
  output_path = "/tmp/image_processor.zip"
}

data "archive_file" "image_info" {
  type        = "zip"
  source_dir  = "${path.module}/lambdas/image_info"
  output_path = "/tmp/image_info.zip"
}

data "archive_file" "get_images" {
  type        = "zip"
  source_dir  = "${path.module}/lambdas/get_images"
  output_path = "/tmp/get_images.zip"
}

data "archive_file" "presigned_url" {
  type        = "zip"
  source_dir  = "${path.module}/lambdas/presigned_url"
  output_path = "/tmp/presigned_url.zip"
}

data "archive_file" "delete_image" {
  type        = "zip"
  source_dir  = "${path.module}/lambdas/delete_image"
  output_path = "/tmp/delete_image.zip"
}

# CloudWatch alarm a képfeldolgozó lambda-hoz
resource "aws_cloudwatch_metric_alarm" "image_processor_timeout" {
  alarm_name          = "image-processor-timeout-alarm-${random_string.suffix.result}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = 60
  statistic           = "Maximum"
  threshold           = 10000
  alarm_actions       = [aws_sns_topic.lambda_timeout_topic.arn]

  dimensions = {
    FunctionName = aws_lambda_function.image_processor.function_name
  }
}

# EventBridge szabály - Minden fájlfeltöltésre triggerel
resource "aws_cloudwatch_event_rule" "s3_image_upload" {
  name        = "s3-image-upload-rule-${random_string.suffix.result}"
  description = "Trigger Step Functions when any file is uploaded to S3"

  event_pattern = jsonencode({
    source = ["aws.s3"]
    detail-type = ["Object Created"]
    detail = {
      bucket = {
        name = [aws_s3_bucket.input_bucket.id]
      }
    }
  })
}

# Step Functions állapotgép - ADATOK ÖSSZEFŰZÉSÉVEL
resource "aws_sfn_state_machine" "image_processing" {
  name     = "image-processing-state-machine-${random_string.suffix.result}"
  role_arn = data.aws_iam_role.lab_role.arn

  definition = jsonencode({
    Comment = "Image processing workflow"
    StartAt = "Format Checker"
    States = {
      "Format Checker" = {
        Type     = "Task"
        Resource = "arn:aws:states:::lambda:invoke"
        Parameters = {
          FunctionName = aws_lambda_function.format_checker.arn
          "Payload.$" = "$"
        }
        ResultPath = "$.format_checker_result"
        Next = "Rekognition"
      }
      "Rekognition" = {
        Type     = "Task"
        Resource = "arn:aws:states:::lambda:invoke"
        Parameters = {
          FunctionName = aws_lambda_function.rekognition.arn
          "Payload.$" = "$.format_checker_result.Payload"
        }
        ResultPath = "$.rekognition_result"
        Next = "Image Processor"
      }
      "Image Processor" = {
        Type     = "Task"
        Resource = "arn:aws:states:::lambda:invoke"
        Parameters = {
          FunctionName = aws_lambda_function.image_processor.arn
          "Payload.$" = "$.rekognition_result.Payload"
        }
        ResultPath = "$.processor_result"
        Next = "Image Info"
      }
      "Image Info" = {
        Type     = "Task"
        Resource = "arn:aws:states:::lambda:invoke"
        Parameters = {
          FunctionName = aws_lambda_function.image_info.arn
          # Összefűzzük a szükséges adatokat
          "Payload" = {
            "filename.$"      = "$.processor_result.Payload.original_key"
            "processed_key.$" = "$.processor_result.Payload.processed_key"
            "upload_time.$"   = "$.processor_result.Payload.upload_time"
            "labels.$"        = "$.rekognition_result.Payload.labels"
          }
        }
        End = true
      }
    }
  })
}

# Egyszerűbb EventBridge target - TELJES EVENT TOVÁBBÍTÁSA
resource "aws_cloudwatch_event_target" "step_functions_target" {
  rule      = aws_cloudwatch_event_rule.s3_image_upload.name
  target_id = "StepFunctions"
  arn       = aws_sfn_state_machine.image_processing.arn
  role_arn  = data.aws_iam_role.lab_role.arn
}

# API Gateway
resource "aws_api_gateway_rest_api" "image_api" {
  name        = "image-processing-api-${random_string.suffix.result}"
  description = "API for image processing application"
}

# API Gateway erőforrások
resource "aws_api_gateway_resource" "images" {
  rest_api_id = aws_api_gateway_rest_api.image_api.id
  parent_id   = aws_api_gateway_rest_api.image_api.root_resource_id
  path_part   = "images"
}

resource "aws_api_gateway_resource" "upload" {
  rest_api_id = aws_api_gateway_rest_api.image_api.id
  parent_id   = aws_api_gateway_rest_api.image_api.root_resource_id
  path_part   = "upload"
}

resource "aws_api_gateway_resource" "image_id" {
  rest_api_id = aws_api_gateway_rest_api.image_api.id
  parent_id   = aws_api_gateway_resource.images.id
  path_part   = "{filename}"
}

# API Gateway metódusok CORS beállításokkal
resource "aws_api_gateway_method" "get_images" {
  rest_api_id   = aws_api_gateway_rest_api.image_api.id
  resource_id   = aws_api_gateway_resource.images.id
  http_method   = "GET"
  authorization = "NONE"
  
  # CORS előkészítés
  request_parameters = {
    "method.request.header.Origin" = false
  }
}

# GET metódus az /upload resource-hoz
resource "aws_api_gateway_method" "get_presigned_url" {
  rest_api_id   = aws_api_gateway_rest_api.image_api.id
  resource_id   = aws_api_gateway_resource.upload.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "delete_image" {
  rest_api_id   = aws_api_gateway_rest_api.image_api.id
  resource_id   = aws_api_gateway_resource.image_id.id
  http_method   = "DELETE"
  authorization = "NONE"
}

# OPTIONS metódus a CORS preflight kérésekhez - UPLOAD resource (JAVÍTVA)
resource "aws_api_gateway_method" "options_upload" {
  rest_api_id   = aws_api_gateway_rest_api.image_api.id
  resource_id   = aws_api_gateway_resource.upload.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "options_upload_integration" {
  rest_api_id   = aws_api_gateway_rest_api.image_api.id
  resource_id   = aws_api_gateway_resource.upload.id
  http_method   = aws_api_gateway_method.options_upload.http_method
  type          = "MOCK"
  
  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
  
  passthrough_behavior = "WHEN_NO_MATCH"
}

resource "aws_api_gateway_method_response" "options_upload_response" {
  rest_api_id = aws_api_gateway_rest_api.image_api.id
  resource_id = aws_api_gateway_resource.upload.id
  http_method = aws_api_gateway_method.options_upload.http_method
  status_code = "200"
  
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
  
  response_models = {
    "application/json" = "Empty"
  }
}

resource "aws_api_gateway_integration_response" "options_upload_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.image_api.id
  resource_id = aws_api_gateway_resource.upload.id
  http_method = aws_api_gateway_method.options_upload.http_method
  status_code = aws_api_gateway_method_response.options_upload_response.status_code
  
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
  
  response_templates = {
    "application/json" = ""
  }
}

# OPTIONS metódus a CORS preflight kérésekhez - DELETE resource
resource "aws_api_gateway_method" "options_delete" {
  rest_api_id   = aws_api_gateway_rest_api.image_api.id
  resource_id   = aws_api_gateway_resource.image_id.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "options_delete_integration" {
  rest_api_id   = aws_api_gateway_rest_api.image_api.id
  resource_id   = aws_api_gateway_resource.image_id.id
  http_method   = aws_api_gateway_method.options_delete.http_method
  type          = "MOCK"
  
  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
  
  passthrough_behavior = "WHEN_NO_MATCH"
}

resource "aws_api_gateway_method_response" "options_delete_response" {
  rest_api_id = aws_api_gateway_rest_api.image_api.id
  resource_id = aws_api_gateway_resource.image_id.id
  http_method = aws_api_gateway_method.options_delete.http_method
  status_code = "200"
  
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration_response" "options_delete_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.image_api.id
  resource_id = aws_api_gateway_resource.image_id.id
  http_method = aws_api_gateway_method.options_delete.http_method
  status_code = aws_api_gateway_method_response.options_delete_response.status_code
  
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'DELETE,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
  
  response_templates = {
    "application/json" = ""
  }
}

# API Gateway integrációk
resource "aws_api_gateway_integration" "get_images_integration" {
  rest_api_id             = aws_api_gateway_rest_api.image_api.id
  resource_id             = aws_api_gateway_resource.images.id
  http_method             = aws_api_gateway_method.get_images.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.get_images.invoke_arn
}

resource "aws_api_gateway_integration" "presigned_url_integration" {
  rest_api_id             = aws_api_gateway_rest_api.image_api.id
  resource_id             = aws_api_gateway_resource.upload.id
  http_method             = aws_api_gateway_method.get_presigned_url.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.presigned_url.invoke_arn
}

resource "aws_api_gateway_integration" "delete_image_integration" {
  rest_api_id             = aws_api_gateway_rest_api.image_api.id
  resource_id             = aws_api_gateway_resource.image_id.id
  http_method             = aws_api_gateway_method.delete_image.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.delete_image.invoke_arn
}

# OPTIONS metódus a CORS preflight kérésekhez - IMAGES resource
resource "aws_api_gateway_method" "options_images" {
  rest_api_id   = aws_api_gateway_rest_api.image_api.id
  resource_id   = aws_api_gateway_resource.images.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "options_images_integration" {
  rest_api_id   = aws_api_gateway_rest_api.image_api.id
  resource_id   = aws_api_gateway_resource.images.id
  http_method   = aws_api_gateway_method.options_images.http_method
  type          = "MOCK"
  passthrough_behavior = "WHEN_NO_MATCH"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "options_images_response" {
  rest_api_id = aws_api_gateway_rest_api.image_api.id
  resource_id = aws_api_gateway_resource.images.id
  http_method = aws_api_gateway_method.options_images.http_method
  status_code = "200"
  
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
  
  response_models = {
    "application/json" = "Empty"
  }
}

resource "aws_api_gateway_integration_response" "options_images_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.image_api.id
  resource_id = aws_api_gateway_resource.images.id
  http_method = aws_api_gateway_method.options_images.http_method
  status_code = aws_api_gateway_method_response.options_images_response.status_code

  response_templates = {
    "application/json" = ""
  }
  
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
}

# API Gateway deployment - MINDEN CORS BEÁLLÍTÁSSAL (JAVÍTVA)
resource "aws_api_gateway_deployment" "image_api_deployment" {
  depends_on = [
    # GET integrációk
    aws_api_gateway_integration.get_images_integration,
    aws_api_gateway_integration.presigned_url_integration,
    aws_api_gateway_integration.delete_image_integration,
    # OPTIONS integrációk
    aws_api_gateway_integration.options_images_integration,
    aws_api_gateway_integration.options_upload_integration,
    aws_api_gateway_integration.options_delete_integration
  ]

  rest_api_id = aws_api_gateway_rest_api.image_api.id

  # Az összes CORS beállítás hash-e a redeploy kikényszerítéséhez
  triggers = {
    redeployment = sha1(jsonencode([
      # Resources
      aws_api_gateway_resource.images.id,
      aws_api_gateway_resource.upload.id,
      aws_api_gateway_resource.image_id.id,
      
      # GET metódusok
      aws_api_gateway_method.get_images.id,
      aws_api_gateway_method.get_presigned_url.id,
      aws_api_gateway_method.delete_image.id,
      
      # OPTIONS metódusok
      aws_api_gateway_method.options_images.id,
      aws_api_gateway_method.options_upload.id,
      aws_api_gateway_method.options_delete.id,
      
      # GET integrációk
      aws_api_gateway_integration.get_images_integration.id,
      aws_api_gateway_integration.presigned_url_integration.id,
      aws_api_gateway_integration.delete_image_integration.id,
      
      # OPTIONS integrációk
      aws_api_gateway_integration.options_images_integration.id,
      aws_api_gateway_integration.options_upload_integration.id,
      aws_api_gateway_integration.options_delete_integration.id,
      
      # OPTIONS method response-ok
      aws_api_gateway_method_response.options_images_response.id,
      aws_api_gateway_method_response.options_upload_response.id,
      aws_api_gateway_method_response.options_delete_response.id,
      
      # OPTIONS integration response-ok
      aws_api_gateway_integration_response.options_images_integration_response.id,
      aws_api_gateway_integration_response.options_upload_integration_response.id,
      aws_api_gateway_integration_response.options_delete_integration_response.id
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Prod stage
resource "aws_api_gateway_stage" "prod" {
  deployment_id = aws_api_gateway_deployment.image_api_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.image_api.id
  stage_name    = "prod"
}

# Lambda engedélyek API Gateway számára
resource "aws_lambda_permission" "get_images_permission" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get_images.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.image_api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "presigned_url_permission" {
  statement_id  = "AllowAPIGatewayInvokePresigned"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.presigned_url.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.image_api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "delete_image_permission" {
  statement_id  = "AllowAPIGatewayInvokeDelete"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.delete_image.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.image_api.execution_arn}/*/*"
}