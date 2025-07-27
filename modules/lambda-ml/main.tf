# modules/lambda-ml/main.tf

data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_exec" {
  name               = "greenhouse-ml-exec-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_cloudwatch" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchEventsFullAccess"
}

resource "aws_lambda_function" "ml" {
  function_name = "greenhouse-ml"
  role          = aws_iam_role.lambda_exec.arn
  s3_bucket     = var.ml_s3_bucket
  s3_key        = var.ml_s3_key
  handler       = "handler.handler"
  runtime       = "python3.11"
  timeout       = 60

  environment {
    variables = {
      MIN_SAMPLES = "10"
      S3_BUCKET   = var.telemetry_bucket
    }
  }
}

resource "aws_cloudwatch_event_rule" "schedule" {
  name                = "ml-schedule"
  schedule_expression = "rate(1 hour)"
}

resource "aws_cloudwatch_event_target" "ml" {
  rule = aws_cloudwatch_event_rule.schedule.name
  arn  = aws_lambda_function.ml.arn
}

resource "aws_lambda_permission" "allow_cloudwatch" {
  statement_id  = "AllowCWInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ml.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.schedule.arn
}
