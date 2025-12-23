resource "aws_cloudwatch_dashboard" "pqc" {
  dashboard_name = "${var.project_name}-pqc-dashboard"

  dashboard_body = jsonencode({
    widgets = [

      # LAMBDA INVOCATIONS (ALL)

      {
        type = "metric"
        x    = 0
        y    = 0
        width  = 12
        height = 6

        properties = {
          title  = "Lambda Invocations (All PQC Services)"
          region = "us-east-1"
          metrics = [
            ["AWS/Lambda", "Invocations", "FunctionName", var.cert_issuer_lambda_name],
            ["AWS/Lambda", "Invocations", "FunctionName", var.attestation_lambda_name],
            ["AWS/Lambda", "Invocations", "FunctionName", "quantum-safe-device-onboard"],
            ["AWS/Lambda", "Invocations", "FunctionName", "dev-scanner"]
          ]
          period = 60
          stat   = "Sum"
        }
      },

      
      # LAMBDA ERRORS (ALL)

      {
        type = "metric"
        x    = 12
        y    = 0
        width  = 12
        height = 6
  
        properties = {
          title = "Lambda Errors (All PQC Services)"
          region = "us-east-1"
          metrics = [
            ["AWS/Lambda", "Errors", "FunctionName", var.cert_issuer_lambda_name],
            ["AWS/Lambda", "Errors", "FunctionName", var.attestation_lambda_name],
            ["AWS/Lambda", "Errors", "FunctionName", "quantum-safe-device-onboard"],
            ["AWS/Lambda", "Errors", "FunctionName", "dev-scanner"]
          ]
          period = 60
          stat   = "Sum"
        }
      },

      # API GATEWAY — 4XX + 5XX
      
      {
        type = "metric"
        x    = 0
        y    = 6
        width  = 12
        height = 6

        properties = {
          title = "API Gateway Errors (4XX & 5XX)"
          region = "us-east-1"
          metrics = [
            ["AWS/ApiGateway", "4XXError", "ApiName", "${var.project_name}-device-onboard-api"],
            ["AWS/ApiGateway", "5XXError", "ApiName", "${var.project_name}-device-onboard-api"]
          ]
          period = 60
          stat   = "Sum"
        }
      },

      # API LATENCY P50 / P95

      {
        type = "metric"
        x    = 12
        y    = 6
        width  = 12
        height = 6

        properties = {
          title = "API Gateway Latency (P50, P95)"
          region = "us-east-1"
          metrics = [
            ["AWS/ApiGateway", "Latency", "ApiName", "${var.project_name}-device-onboard-api", { "stat": "p50" }],
            ["AWS/ApiGateway", "Latency", "ApiName", "${var.project_name}-device-onboard-api", { "stat": "p95" }]
          ]
          period = 60
        }
      },

      # S3 CERT ISSUER TRIGGERING
      
      {
        type = "metric"
        x    = 0
        y    = 12
        width  = 12
        height = 6

        properties = {
          title  = "S3 ObjectCreated Events (CSR Pipeline)"
          region = "us-east-1"
          metrics = [
            ["AWS/S3", "NumberOfObjects", "BucketName", "quantum-safe-artifacts-dev", "StorageType", "AllStorageTypes"]
          ]
          period = 300
          stat   = "Average"
        }
      },

      # PCA — CERTIFICATE ISSUANCE
    
      {
        type = "metric"
        x    = 12
        y    = 12
        width  = 12
        height = 6

        properties = {
          title = "ACM PCA Certificate Issues"
          region = "us-east-1"
          metrics = [
            ["AWS/ACMPCA", "CertificatesIssued", "CertificateAuthorityArn", var.subordinate_ca_arn]
          ]
          period = 300
          stat   = "Sum"
        }
      },

      
      # DYNAMODB STATUS
      
      {
        type = "metric"
        x    = 0
        y    = 18
        width  = 12
        height = 6

        properties = {
          title = "DynamoDB Throttles (Device Registry)"
          region = "us-east-1"
          metrics = [
            ["AWS/DynamoDB", "ReadThrottleEvents", "TableName", "quantum-safe-device-registry"],
            ["AWS/DynamoDB", "WriteThrottleEvents", "TableName", "quantum-safe-device-registry"]
          ]
          period = 60
          stat   = "Sum"
        }
      },

      
      # PQC COMPLIANCE PIE CHART
      
      {
        type = "metric"
        x    = 12
        y    = 18
        width  = 12
        height = 6

        properties = {
          title = "PQC Compliance State Breakdown"
          region = "us-east-1"
          view   = "pie"
          metrics = [
            ["Custom/PQC", "pqc_ok"],
            ["Custom/PQC", "legacy"]
          ]
        }
      }
    ]
  })
}
