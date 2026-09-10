terraform {
    required_providers{
        aws= {
            source ="hashicorp/aws"
            version ="~> 5.0"
        }
    }
    required_version = ">= 1.2.0"
}

provider "aws" {
  region = "us-east-1"
}

# 1. Private S3 Bucket for Website Content
resource "aws_s3_bucket" "resume_bucket" {
  bucket_prefix = "cloud-resume-site-"
}

# 2. CloudFront Origin Access Control (OAC)
resource "aws_cloudfront_origin_access_control" "oac" {
  name                              = "resume-s3-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# 3. S3 Bucket Policy (Restricts access solely to CloudFront)
resource "aws_s3_bucket_policy" "allow_cloudfront" {
  bucket = aws_s3_bucket.resume_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowCloudFrontServicePrincipalReadOnly"
        Effect    = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.resume_bucket.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.cdn.arn
          }
        }
      }
    ]
  })
}

# 4. CloudFront Distribution
resource "aws_cloudfront_distribution" "cdn" {
  enabled             = true
  default_root_object = "index.html"

  origin {
    domain_name              = aws_s3_bucket.resume_bucket.bucket_regional_domain_name
    origin_id                = "S3Origin"
    origin_access_control_id = aws_cloudfront_origin_access_control.oac.id
  }

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3Origin"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  # Custom Error Responses to fix sub-page 403/404 routing errors
  custom_error_response {
    error_code            = 403
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 10
  }

  custom_error_response {
    error_code            = 404
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 10
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

# Outputs
output "cloudfront_url" {
  value       = "https://${aws_cloudfront_distribution.cdn.domain_name}"
  description = "Live CloudFront URL"
}

output "s3_bucket_name" {
  value       = aws_s3_bucket.resume_bucket.id
  description = "Name of the created S3 bucket"
}

# 1. DynamoDB Table for Storing Visitor Count
resource "aws_dynamodb_table" "visitor_count" {
  name         = "cloud-resume-visitor-count"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }
}

# Initial seed item
resource "aws_dynamodb_table_item" "initial_counter" {
  table_name = aws_dynamodb_table.visitor_count.name
  hash_key   = aws_dynamodb_table.visitor_count.hash_key

  item = <<ITEM
{
  "id": {"S": "visitors"},
  "count": {"N": "0"}
}
ITEM
}

# 2. Archive local Lambda Python script into a ZIP file
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/func.py"
  output_path = "${path.module}/lambda/func.zip"
}

# 3. IAM Role for Lambda
resource "aws_iam_role" "lambda_exec_role" {
  name = "cloud_resume_lambda_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

# Attach policy to allow Lambda to read/write DynamoDB
resource "aws_iam_role_policy" "lambda_dynamodb_policy" {
  name = "lambda_dynamodb_policy"
  role = aws_iam_role.lambda_exec_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["dynamodb:GetItem", "dynamodb:UpdateItem"]
      Resource = aws_dynamodb_table.visitor_count.arn
    }]
  })
}

# Basic execution policy for CloudWatch Logs
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# 4. AWS Lambda Function
resource "aws_lambda_function" "visitor_counter" {
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  function_name    = "cloud-resume-visitor-counter"
  role             = aws_iam_role.lambda_exec_role.arn
  handler          = "func.lambda_handler"
  runtime          = "python3.12"
}

# 5. API Gateway (HTTP API v2)
resource "aws_apigatewayv2_api" "http_api" {
  name          = "cloud-resume-api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["GET", "OPTIONS"]
    allow_headers = ["*"]
  }
}

resource "aws_apigatewayv2_stage" "default_stage" {
  api_id      = aws_apigatewayv2_api.http_api.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id           = aws_apigatewayv2_api.http_api.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.visitor_counter.invoke_arn
}

resource "aws_apigatewayv2_route" "counter_route" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "GET /count"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

# Grant API Gateway permission to invoke Lambda
resource "aws_lambda_permission" "api_gw_permission" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.visitor_counter.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http_api.execution_arn}/*/*"
}

# Output the API endpoint URL
output "api_endpoint" {
  value       = "${aws_apigatewayv2_api.http_api.api_endpoint}/count"
  description = "HTTP API Gateway URL for visitor counter"
}