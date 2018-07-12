provider "archive" {}

data "archive_file" "measurements_lambda_zip" {
    type        = "zip"
    source_file = "measurements.js"
    output_path = "measurements-lambda.zip"
}

provider "aws" {
  region     = "us-east-1"
}

variable "region" {
  type = "string"
  default = "us-east-1"
}

variable "accountId" {
  type = "string"
}

resource "aws_api_gateway_rest_api" "OpenAQMeasurementsAPI" {
  name        = "OpenAQMeasurementsAPI"
  description = "This is my OpenAQ API"
  endpoint_configuration {
    types = ["REGIONAL"]
  }  
}

resource "aws_api_gateway_resource" "MeasurementsResource" {
  rest_api_id = "${aws_api_gateway_rest_api.OpenAQMeasurementsAPI.id}"
  parent_id   = "${aws_api_gateway_rest_api.OpenAQMeasurementsAPI.root_resource_id}"
  path_part   = "measurements"
}

resource "aws_api_gateway_method" "MeasurementsMethodGet" {
  rest_api_id   = "${aws_api_gateway_rest_api.OpenAQMeasurementsAPI.id}"
  resource_id   = "${aws_api_gateway_resource.MeasurementsResource.id}"
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_resource" "QueriesResource" {
  rest_api_id = "${aws_api_gateway_rest_api.OpenAQMeasurementsAPI.id}"
  parent_id   = "${aws_api_gateway_rest_api.OpenAQMeasurementsAPI.root_resource_id}"
  path_part   = "queries"
}

resource "aws_api_gateway_resource" "QueryByIdResource" {
  rest_api_id = "${aws_api_gateway_rest_api.OpenAQMeasurementsAPI.id}"
  parent_id   = "${aws_api_gateway_resource.QueriesResource.id}"
  path_part   = "{queryId}"
}

resource "aws_api_gateway_method" "QueriesResourceGetByQueryID" {
  rest_api_id   = "${aws_api_gateway_rest_api.OpenAQMeasurementsAPI.id}"
  resource_id   = "${aws_api_gateway_resource.QueryByIdResource.id}"
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_stage" "dev" {
  stage_name = "dev"
  rest_api_id = "${aws_api_gateway_rest_api.OpenAQMeasurementsAPI.id}"
  deployment_id = "${aws_api_gateway_deployment.devDeployment.id}"
}

resource "aws_api_gateway_deployment" "devDeployment" {
  depends_on = [
    "aws_api_gateway_integration.MeasurementsGetIntegration",
  ]

  rest_api_id = "${aws_api_gateway_rest_api.OpenAQMeasurementsAPI.id}"
  stage_name = "dev"
}

resource "aws_api_gateway_integration" "MeasurementsGetIntegration" {
  rest_api_id             = "${aws_api_gateway_rest_api.OpenAQMeasurementsAPI.id}"
  resource_id             = "${aws_api_gateway_resource.MeasurementsResource.id}"
  http_method             = "${aws_api_gateway_method.MeasurementsMethodGet.http_method}"
  integration_http_method = "GET"
  type                    = "AWS_PROXY"
  uri                     = "${aws_lambda_function.openAQ-getMeasurements.invoke_arn}"
}

resource "aws_api_gateway_integration" "QueryByIdGetIntegration" {
  rest_api_id             = "${aws_api_gateway_rest_api.OpenAQMeasurementsAPI.id}"
  resource_id             = "${aws_api_gateway_resource.QueryByIdResource.id}"
  http_method             = "${aws_api_gateway_method.QueriesResourceGetByQueryID.http_method}"
  integration_http_method = "GET"
  type                    = "AWS_PROXY"
  uri                     = "arn:aws:apigateway:${var.region}:lambda:path/2015-03-31/functions/arn:aws:lambda:us-east-1:${var.accountId}:function:openaqApi-queryId-GET/invocations"
}

resource "aws_api_gateway_method_response" "Measurements200" {
    rest_api_id = "${aws_api_gateway_rest_api.OpenAQMeasurementsAPI.id}"
    resource_id = "${aws_api_gateway_resource.MeasurementsResource.id}"
    http_method = "${aws_api_gateway_method.MeasurementsMethodGet.http_method}"
    status_code = "200"

    response_models = {
         "application/json" = "Empty"
    }
}

resource "aws_api_gateway_integration_response" "MeasurementsMethodGetResponse" {
  rest_api_id = "${aws_api_gateway_rest_api.OpenAQMeasurementsAPI.id}"
  resource_id = "${aws_api_gateway_resource.MeasurementsResource.id}"
  http_method = "${aws_api_gateway_method.MeasurementsMethodGet.http_method}"
  status_code = "${aws_api_gateway_method_response.Measurements200.status_code}"

  response_templates = {
     "application/json" = ""
  } 
}

resource "aws_api_gateway_method_response" "Queries200" {
    rest_api_id = "${aws_api_gateway_rest_api.OpenAQMeasurementsAPI.id}"
    resource_id = "${aws_api_gateway_resource.QueryByIdResource.id}"
    http_method = "${aws_api_gateway_method.QueriesResourceGetByQueryID.http_method}"
    status_code = "200"

    response_models = {
         "application/json" = "Empty"
    }
}

resource "aws_api_gateway_integration_response" "QueryByIdMethodGetResponse" {
  rest_api_id = "${aws_api_gateway_rest_api.OpenAQMeasurementsAPI.id}"
  resource_id = "${aws_api_gateway_resource.QueryByIdResource.id}"
  http_method = "${aws_api_gateway_method.QueriesResourceGetByQueryID.http_method}"
  status_code = "${aws_api_gateway_method_response.Queries200.status_code}"

  response_templates = {
     "application/json" = ""
  } 
}

resource "aws_lambda_function" "openAQ-getMeasurements" {
  filename         = "measurements-lambda.zip"
  function_name    = "openAQ-getMeasurements"
  # TODO: Add role to tf plan
  role             = "arn:aws:iam::${var.accountId}:role/service-role/lambdaRole"
  handler          = "measurements.handler"
  runtime          = "nodejs8.10"
  source_code_hash = "${base64sha256(file("measurements-lambda.zip"))}"

  environment {
    variables = {
      OUTPUT_LOCATION = "s3://aws-athena-query-results-openaq"
    }
  }
}

resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.openAQ-getMeasurements.arn}"
  principal     = "apigateway.amazonaws.com"

  # The /*/* portion grants access from any method on any resource
  # within the API Gateway "REST API".
  source_arn = "arn:aws:execute-api:${var.region}:${var.accountId}:${aws_api_gateway_rest_api.OpenAQMeasurementsAPI.id}/*/${aws_api_gateway_method.MeasurementsMethodGet.http_method}${aws_api_gateway_resource.MeasurementsResource.path}"
}

