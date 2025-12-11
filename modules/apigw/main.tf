# REST API

resource "aws_api_gateway_rest_api" "device_onboard" {
  name = "${var.project_name}-device-onboard-api"
}

# RESOURCE: /onboard

resource "aws_api_gateway_resource" "onboard" {
  rest_api_id = aws_api_gateway_rest_api.device_onboard.id
  parent_id   = aws_api_gateway_rest_api.device_onboard.root_resource_id
  path_part   = "onboard"
}

# METHOD: POST

resource "aws_api_gateway_method" "post_onboard" {
  rest_api_id   = aws_api_gateway_rest_api.device_onboard.id
  resource_id   = aws_api_gateway_resource.onboard.id
  http_method   = "POST"
  authorization = "NONE"
}


# INTEGRATION - LAMBDA

resource "aws_api_gateway_integration" "onboard_lambda" {
  rest_api_id             = aws_api_gateway_rest_api.device_onboard.id
  resource_id             = aws_api_gateway_resource.onboard.id
  http_method             = aws_api_gateway_method.post_onboard.http_method
    
    type                    = "AWS_PROXY"
    integration_http_method = "POST"
    uri                     = var.lambda_invoke_arn
}


# DEPLOYMENT

resource "aws_api_gateway_deployment" "deployment" {
  rest_api_id = aws_api_gateway_rest_api.device_onboard.id

  depends_on = [
    aws_api_gateway_integration.onboard_lambda
  ]

  triggers = {
    redeploy = timestamp()
  }

  lifecycle {
    create_before_destroy = true
  }
}

# STAGE

resource "aws_api_gateway_stage" "dev" {
  rest_api_id   = aws_api_gateway_rest_api.device_onboard.id
  deployment_id = aws_api_gateway_deployment.deployment.id
  stage_name    = var.environment

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gw_logs.arn
    format          = "$context.requestId - $context.status - $context.error.message"
  }

  depends_on = [
    aws_api_gateway_account.account
  ]
}

# LAMBDA PERMISSION

resource "aws_lambda_permission" "allow_apigw" {
  statement_id  = "AllowAPIGWInvoke"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "arn:aws:execute-api:${var.region}:${var.account_id}:${aws_api_gateway_rest_api.device_onboard.id}/${var.environment}/POST/onboard"
}

#LOGGING

resource "aws_cloudwatch_log_group" "api_gw_logs" {
  name = "/aws/apigateway/${var.project_name}-logs"
  retention_in_days = 14
}
