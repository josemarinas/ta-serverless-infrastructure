
provider "aws" {
  version = "~> 2.8"
  region  = "eu-west-1"
}
##############
### QUEUES ###
##############
module "sqs-input" {
  source  = "terraform-aws-modules/sqs/aws"
  version = "2.0.0"
  name    = "ta-input-queue"
  tags = {
    Name = "ta-input-queue"
    Flow = "input"
  }
}
module "sqs-output" {
  source  = "terraform-aws-modules/sqs/aws"
  version = "2.0.0"
  name    = "ta-output-queue"
  tags = {
    Name = "ta-output-queue"
    Flow = "output"
  }
}
##############
### QUEUES ###
##############
resource "aws_lambda_event_source_mapping" "this" {
  event_source_arn = module.sqs-input.this_sqs_queue_arn
  function_name    = aws_lambda_function.this.arn
}


resource "aws_lambda_function" "this" {
  filename      = "../ta-serverless-system/main.zip"
  function_name = "EchoAndSearch"
  role          = aws_iam_role.iam_for_lambda.arn
  handler       = "main"
  memory_size   = 256

  runtime = "go1.x"

  environment {
    variables = {
      AWS_OUTPUT_QUEUE = "https://sqs.eu-west-1.amazonaws.com/020719736547/ta-output-queue"
      AWS_BUCKET       = "ta-bucket-josemarinas"
    }
  }
}
resource "aws_iam_role" "iam_for_lambda" {
  name = "iam_for_lambda"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = "${aws_iam_role.iam_for_lambda.name}"
  policy_arn = "${aws_iam_policy.lambda_policy.arn}"
}
resource "aws_iam_policy" "lambda_policy" {
  name = "policy_for_lambda"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:DescribeSecurityGroups",
        "ec2:DescribeSubnets",
        "ec2:DescribeVpcs",
        "events:*",
        "kms:ListAliases",
        "lambda:*",
        "logs:*",
        "s3:*",
        "sqs:*"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}
##################
### S3 BUCKETS ###
##################
resource "aws_s3_bucket" "ta" {
  force_destroy = true
  bucket        = "ta-bucket-josemarinas"
  region        = "eu-west-1"
  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["PUT", "POST", "GET", "DELETE"]
    allowed_origins = ["*"]
    max_age_seconds = 3000
  }
}

resource "aws_s3_bucket" "www" {
  force_destroy = true
  bucket        = "ta-serverless-frontend"
  acl           = "public-read"
  policy        = <<POLICY
{ 
"Statement": [    
    {      
      "Effect": "Allow",      
      "Principal": "*",      
      "Action": "s3:GetObject",      
      "Resource": "arn:aws:s3:::ta-serverless-frontend/*"    
    }
  ]
}
POLICY
  website {
    index_document = "index.html"
    error_document = "index.html"
  }
}

# resource "aws_s3_bucket_object" "object" {
#   bucket = aws_s3_bucket.www.bucket
#   key    = "/"
#   source = "../ta-frontend/dist/"

#   # The filemd5() function is available in Terraform 0.11.12 and later
#   # For Terraform 0.11.11 and earlier, use the md5() function and the file() function:
#   # etag = "${md5(file("path/to/file"))}"
#   # etag = "${filemd5("../ta-frontend/dist/")}"
# }

