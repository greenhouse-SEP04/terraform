resource "aws_lambda_function" "ml" {
  function_name = "greenhouse-ml"
  role          = aws_iam_role.lambda_exec.arn
  filename      = "build/ml_service.zip"
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
  rule      = aws_cloudwatch_event_rule.schedule.name
  arn       = aws_lambda_function.ml.arn
}

resource "aws_lambda_permission" "allow_cloudwatch" {
  statement_id  = "AllowCWInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ml.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.schedule.arn
}