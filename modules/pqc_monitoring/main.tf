resource "aws_cloudwatch_dashboard" "pqc" {
  dashboard_name = "${var.project_name}-pqc-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 8
        height = 6

        properties = {
          title = "Cert Issuer Lambda Errors"
          region = "us-east-1"
          metrics = [
            [
              "AWS/Lambda",
              "Errors",
              "FunctionName",
              var.cert_issuer_lambda_name
            ]
          ]
          stat   = "Sum"
          period = 60
        }
      },
      {
        type   = "metric"
        x      = 8
        y      = 0
        width  = 8
        height = 6

        properties = {
          title = "Attestation Lambda Errors"
          region = "us-east-1"
          metrics = [
            [
              "AWS/Lambda",
              "Errors",
              "FunctionName",
              var.attestation_lambda_name
            ]
          ]
          stat   = "Sum"
          period = 60
        }
      }
    ]
  })
}
