resource "aws_apigatewayv2_api" "processed_images_api" {
  name          = "get-processed-images-api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["GET", "POST", "PUT", "DELETE", "OPTIONS"]
    allow_headers = ["*"]
    max_age       = 300
  }
}

resource "aws_apigatewayv2_integration" "api_integration" {
  api_id                 = aws_apigatewayv2_api.processed_images_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.image_get_lambda.arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "api_route" {
  api_id    = aws_apigatewayv2_api.processed_images_api.id
  route_key = "GET /"
  target    = "integrations/${aws_apigatewayv2_integration.api_integration.id}"
}

resource "aws_apigatewayv2_stage" "api_stage" {
  name        = "stage"
  api_id      = aws_apigatewayv2_api.processed_images_api.id
  auto_deploy = true
}

output "api_gateway_invoke_url" {
  value = aws_apigatewayv2_api.processed_images_api.api_endpoint
}

resource "aws_lambda_permission" "image_get_lambda_permission" {
  statement_id  = "APIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.image_get_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.processed_images_api.execution_arn}/*/*"
}

resource "aws_apigatewayv2_integration" "get_presigned_url_lambda_integration" {
  api_id                 = aws_apigatewayv2_api.processed_images_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.get_presigned_url_lambda.arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "get_presigned_url_lambda_route" {
  api_id    = aws_apigatewayv2_api.processed_images_api.id
  route_key = "GET /get-upload-url"
  target    = "integrations/${aws_apigatewayv2_integration.get_presigned_url_lambda_integration.id}"
}

resource "aws_lambda_permission" "get_presigned_url_lambda_permission" {
  statement_id  = "APIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get_presigned_url_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.processed_images_api.execution_arn}/*/*"
}

resource "aws_apigatewayv2_integration" "image_delete_lambda_integration" {
  api_id                 = aws_apigatewayv2_api.processed_images_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.image_delete_lambda.arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "image_delete_lambda_route" {
  api_id    = aws_apigatewayv2_api.processed_images_api.id
  route_key = "DELETE /delete"
  target    = "integrations/${aws_apigatewayv2_integration.image_delete_lambda_integration.id}"
}

resource "aws_lambda_permission" "image_delete_lambda_permission" {
  statement_id  = "APIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.image_delete_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.processed_images_api.execution_arn}/*/*"
}