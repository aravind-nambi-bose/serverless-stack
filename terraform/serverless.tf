provider "aws" {
  profile    = "default"
  region     = "us-east-2"
}

variable "myregion" {
  type = string
  default = "us-east-2"
}

variable "accountId" {
  type = string
  default = "xxxx"
}

resource "aws_api_gateway_rest_api" "ServerlessTestAPI" {
  name        = "ServerlessTestAPI"
  description = "Serverless Test  API"
}

resource "aws_api_gateway_resource" "ServerlessTestAPIResource" {
  rest_api_id = "${aws_api_gateway_rest_api.ServerlessTestAPI.id}"
  parent_id   = "${aws_api_gateway_rest_api.ServerlessTestAPI.root_resource_id}"
  path_part        = "test"
}

resource "aws_api_gateway_method" "ServerlessTestAPIMethod" {
  rest_api_id   = "${aws_api_gateway_rest_api.ServerlessTestAPI.id}"
  resource_id   = "${aws_api_gateway_resource.ServerlessTestAPIResource.id}"
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "ServerlessTestAPIIntegration" {
  rest_api_id             = "${aws_api_gateway_rest_api.ServerlessTestAPI.id}"
  resource_id             = "${aws_api_gateway_resource.ServerlessTestAPIResource.id}"
  http_method             = "${aws_api_gateway_method.ServerlessTestAPIMethod.http_method}"
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "arn:aws:apigateway:${var.myregion}:lambda:path/2015-03-31/functions/${aws_lambda_function.ServerlessTestLambda.arn}/invocations"
}

# Lambda
resource "aws_lambda_permission" "apigw_lambda" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.ServerlessTestLambda.function_name}"
  principal     = "apigateway.amazonaws.com"

  # More: http://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-control-access-using-iam-policies-to-invoke-api.html
  source_arn = "arn:aws:execute-api:${var.myregion}:${var.accountId}:${aws_api_gateway_rest_api.ServerlessTestAPI.id}/*/${aws_api_gateway_method.ServerlessTestAPIMethod.http_method}${aws_api_gateway_resource.ServerlessTestAPIResource.path}"
}

resource "aws_lambda_function" "ServerlessTestLambda" {
  filename      = "../bin/api-lambda.zip"
  function_name = "serverlesstestlambda"
  role          = "${aws_iam_role.role.arn}"
  handler       = "api_lambda.lambda_handler"
  runtime       = "python3.7"

  source_code_hash = "${filebase64sha256("../bin/api-lambda.zip")}"
}

resource "aws_dynamodb_table" "serverlesstest-dynamodb-table" {
  name           = "serverlesstesttable"
  billing_mode   = "PROVISIONED"
  stream_enabled   = true
  stream_view_type = "NEW_IMAGE"
  read_capacity  = 1
  write_capacity = 5
  hash_key       = "id"

  attribute {
    name = "id"
    type = "S"
  }

  ttl {
    attribute_name = "ExpirationTime"
    enabled        = true
  }

}

resource "aws_lambda_function" "ServerlessTestStreamLambda" {
  filename      = "../bin/stream-lambda.zip"
  function_name = "serverlessteststreamlambda"
  role          = "${aws_iam_role.role.arn}"
  handler       = "stream_lambda.lambda_handler"
  runtime       = "python3.7"

  source_code_hash = "${filebase64sha256("../bin/stream-lambda.zip")}"

  environment {
    variables = {
      email_sns = "${aws_sns_topic.serverlesstestsns.arn}"
    }
  }
}

resource "aws_lambda_event_source_mapping" "ServerlessTestStreamLambdaMapping" {
  event_source_arn  = "${aws_dynamodb_table.serverlesstest-dynamodb-table.stream_arn}"
  function_name     = "${aws_lambda_function.ServerlessTestStreamLambda.arn}"
  starting_position = "LATEST"
  batch_size = 5
}

resource "aws_sns_topic" "serverlesstestsns" {
  name = "serverlesstest-topic"
}


# IAM
resource "aws_iam_role" "role"{
  name = "serverlesstest-role"

  assume_role_policy = <<POLICY
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
POLICY
}

# POLICIES
resource "aws_iam_role_policy" "serverlesstest-dynamodb-lambda-policy"{
  name = "serverlesstest-dynamodb-lambda-policy"
  role = "${aws_iam_role.role.id}"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:*"
      ],
      "Resource": [
        "${aws_dynamodb_table.serverlesstest-dynamodb-table.arn}",
        "${aws_dynamodb_table.serverlesstest-dynamodb-table.stream_arn}"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "sns:*"
      ],
      "Resource": "${aws_sns_topic.serverlesstestsns.arn}"
    },
    {
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Effect": "Allow",
      "Resource": "arn:aws:logs:*:*:*"
    }
  ]
}
EOF
}
