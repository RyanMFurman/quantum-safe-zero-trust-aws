# ==========================================
# REST API
# ==========================================
resource "aws_api_gateway_rest_api" "device_onboard" {
  name = "${var.project_name}-device-onboard-api"
}

# ==========================================
# REQUEST VALIDATOR + MODELS (NEW)
# ==========================================
resource "aws_api_gateway_request_validator" "validate_body" {
  rest_api_id = aws_api_gateway_rest_api.device_onboard.id
  name        = "validate-body"
  validate_request_body = true
}

resource "aws_api_gateway_model" "onboard_request" {
  rest_api_id  = aws_api_gateway_rest_api.device_onboard.id
  name         = "OnboardRequest"
  content_type = "application/json"

  schema = jsonencode({
    type       = "object",
    required   = ["device_id"],
    properties = {
      device_id = { type = "string" }
    }
  })
}

resource "aws_api_gateway_model" "attest_submit_request" {
  rest_api_id  = aws_api_gateway_rest_api.device_onboard.id
  name         = "AttestSubmitRequest"
  content_type = "application/json"

  schema = jsonencode({
    type       = "object",
    required   = ["device_id"],
    properties = {
      device_id = { type = "string" },
      challenge = { type = "string" },
      signature = { type = "string" }
    }
  })
}

# ==========================================
# RESOURCE: /onboard
# ==========================================

resource "aws_api_gateway_resource" "onboard" {
  rest_api_id = aws_api_gateway_rest_api.device_onboard.id
  parent_id   = aws_api_gateway_rest_api.device_onboard.root_resource_id
  path_part   = "onboard"
}

resource "aws_api_gateway_method" "post_onboard" {
  rest_api_id   = aws_api_gateway_rest_api.device_onboard.id
  resource_id   = aws_api_gateway_resource.onboard.id
  http_method   = "POST"
  authorization = "NONE"

  request_validator_id = aws_api_gateway_request_validator.validate_body.id

  request_models = {
    "application/json" = aws_api_gateway_model.onboard_request.name
  }
}

resource "aws_api_gateway_integration" "onboard_lambda" {
  rest_api_id             = aws_api_gateway_rest_api.device_onboard.id
  resource_id             = aws_api_gateway_resource.onboard.id
  http_method             = aws_api_gateway_method.post_onboard.http_method
  type                    = "AWS_PROXY"
  integration_http_method = "POST"
  uri                     = var.lambda_invoke_arn
}

# ==========================================
# RESOURCE: /attest
# ==========================================

resource "aws_api_gateway_resource" "attest" {
  rest_api_id = aws_api_gateway_rest_api.device_onboard.id
  parent_id   = aws_api_gateway_rest_api.device_onboard.root_resource_id
  path_part   = "attest"
}

resource "aws_api_gateway_method" "post_attest" {
  rest_api_id   = aws_api_gateway_rest_api.device_onboard.id
  resource_id   = aws_api_gateway_resource.attest.id
  http_method   = "POST"
  authorization = "NONE"

  request_validator_id = aws_api_gateway_request_validator.validate_body.id

  request_models = {
    "application/json" = aws_api_gateway_model.attest_submit_request.name
  }
}

resource "aws_api_gateway_integration" "attest_lambda" {
  rest_api_id             = aws_api_gateway_rest_api.device_onboard.id
  resource_id             = aws_api_gateway_resource.attest.id
  http_method             = aws_api_gateway_method.post_attest.http_method
  type                    = "AWS_PROXY"
  integration_http_method = "POST"
  uri                     = var.attestation_lambda_invoke_arn
}

# ==========================================
# DEPLOYMENT + STAGE
# ==========================================
resource "aws_api_gateway_deployment" "deployment" {
  rest_api_id = aws_api_gateway_rest_api.device_onboard.id

  depends_on = [
    aws_api_gateway_integration.onboard_lambda,
    aws_api_gateway_integration.attest_lambda
  ]

  triggers = {
    redeploy = timestamp()
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "dev" {
  rest_api_id   = aws_api_gateway_rest_api.device_onboard.id
  deployment_id = aws_api_gateway_deployment.deployment.id
  stage_name    = var.environment

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gw_logs.arn
    format          = "$context.requestId - $context.status - $context.error.message"
  }

  depends_on = [aws_api_gateway_account.account]
}

# ======================== ==================
# PERMISSIONS
# ==========================================
resource "aws_lambda_permission" "allow_apigw_attest" {
  statement_id  = "AllowAPIGWInvokeAttest"
  action        = "lambda:InvokeFunction"
  function_name = var.attestation_lambda_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "arn:aws:execute-api:${var.region}:${var.account_id}:${aws_api_gateway_rest_api.device_onboard.id}/${var.environment}/POST/attest"
}

# ==========================================
# LOGS
# ==========================================
resource "aws_cloudwatch_log_group" "api_gw_logs" {
  name              = "/aws/apigateway/${var.project_name}-logs"
  retention_in_days = 14
}
