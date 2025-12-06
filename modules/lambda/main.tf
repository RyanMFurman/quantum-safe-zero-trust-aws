
# Lambda: Artifact Scanner

resource "aws_cloudwatch_log_group" "scanner" {
  name              = "/aws/lambda/${var.project_name}-scanner"
  retention_in_days = 14
}

resource "aws_sqs_queue" "dlq" {
  name = "${var.project_name}-scanner-dlq"
}

resource "aws_lambda_function" "scanner" {
  function_name = "${var.project_name}-scanner"
  role          = var.lambda_scanner_role_arn
  handler       = "scanner.handler"
  runtime       = "python3.12"
  timeout       = 30

  filename         = "${path.module}/scanner.zip"
  source_code_hash = filebase64sha256("${path.module}/scanner.zip")

  environment {
    variables = {
      KMS_KEY_ARN = var.kms_key_arn
    }
  }

  dead_letter_config {
    target_arn = aws_sqs_queue.dlq.arn
  }

  # reserved_concurrent_executions removed for now due to AWS limits

  logging_config {
    log_format = "Text"
  }

  depends_on = [
    aws_cloudwatch_log_group.scanner
  ]
}

resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.scanner.arn
  principal     = "s3.amazonaws.com"
  source_arn    = var.bucket_arn
}

# CloudWatch Alarm for Lambda errors
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "${var.project_name}-scanner-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 60
  statistic           = "Sum"
  threshold           = 1

  alarm_description = "Triggers if Lambda scanner fails"
  dimensions = {
    FunctionName = aws_lambda_function.scanner.function_name
  }
}