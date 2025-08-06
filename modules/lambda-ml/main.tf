# ───────────────────────────────────────────────────────────────────────────────
# modules/lambda-ml/main.tf
# ───────────────────────────────────────────────────────────────────────────────

data "aws_iam_policy_document" "assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}


resource "aws_iam_role" "exec" {
  name               = "greenhouse-ml-zip-exec"
  assume_role_policy = data.aws_iam_policy_document.assume.json
}

resource "aws_iam_role_policy_attachment" "basic" {
  role       = aws_iam_role.exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# S3 access to telemetry bucket (reads training.csv & writes model.joblib)
data "aws_iam_policy_document" "s3_access" {
  statement {
    actions   = ["s3:ListBucket"]
    resources = ["arn:aws:s3:::${var.telemetry_bucket}"]
  }
  statement {
    actions   = ["s3:GetObject", "s3:PutObject"]
    resources = ["arn:aws:s3:::${var.telemetry_bucket}/*"]
  }
}

resource "aws_iam_policy" "s3_access" {
  name   = "greenhouse-ml-zip-s3"
  policy = data.aws_iam_policy_document.s3_access.json
}

resource "aws_iam_role_policy_attachment" "s3_attach" {
  role       = aws_iam_role.exec.name
  policy_arn = aws_iam_policy.s3_access.arn
}


resource "aws_cloudwatch_log_group" "logs" {
  name              = "/aws/lambda/greenhouse-ml"
  retention_in_days = 7
}


# ───────────────────────────────────────────────────────────────────────────────
# LAMBDA LAYERS for heavy packages (numpy, pandas, sklearn…)
# ───────────────────────────────────────────────────────────────────────────────

resource "aws_lambda_layer_version" "sk1" {
  layer_name          = "gh-ml-sk1"
  filename            = "${path.root}/../mal/.lambda_layers/sk1.zip"
  compatible_runtimes = ["python3.11"]
}

resource "aws_lambda_layer_version" "sk2" {
  layer_name          = "gh-ml-sk2"
  filename            = "${path.root}/../mal/.lambda_layers/sk2.zip"
  compatible_runtimes = ["python3.11"]
}

# ───────────────────────────────────────────────────────────────────────────────
# ZIP-packaged Lambda function (only handler, deps come from layers)
# ───────────────────────────────────────────────────────────────────────────────

resource "aws_lambda_function" "ml" {
  function_name = "greenhouse-ml"
  role          = aws_iam_role.exec.arn

  runtime = "python3.11"
  handler = "handler.handler"

  # your tiny handler ZIP in S3
  s3_bucket = var.ml_artifact_bucket
  s3_key    = var.ml_artifact_key

  # attach the two layers
  layers = [
    aws_lambda_layer_version.sk1.arn,
    aws_lambda_layer_version.sk2.arn,
  ]

  timeout = 60

  environment {
    variables = {
      MIN_SAMPLES        = "10"
      S3_BUCKET          = var.telemetry_bucket
      AWS_DEFAULT_REGION = "us-east-1"
  #   AWS_ENDPOINT_URL   = "http://localhost:4566"
    }
  }

  depends_on = [aws_cloudwatch_log_group.logs]
}


resource "aws_cloudwatch_event_rule" "schedule" {
  name                = "ml-schedule"
  schedule_expression = var.schedule_expression
}

resource "aws_cloudwatch_event_target" "target" {
  rule = aws_cloudwatch_event_rule.schedule.name
  arn  = aws_lambda_function.ml.arn

  input = jsonencode({
    action        = "train"
    s3_uri        = "s3://${var.telemetry_bucket}/ml/training.csv"
    target        = "target"
    model         = "rf_cls"
    greenhouse_id = "gh-001"
  })
}

resource "aws_lambda_permission" "allow_events" {
  statement_id  = "AllowCWInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ml.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.schedule.arn
}
