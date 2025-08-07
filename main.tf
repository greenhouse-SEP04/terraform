# ───────────────────────────────────────────────────────────────────────────────
# 0. ML artifacts from GitHub Releases (Option A)
#    - Writes files to ../mal/.lambda_layers/{sk1.zip,sk2.zip} and
#      ../mal/build/ml_service.zip so the rest of the config can use them.
# ───────────────────────────────────────────────────────────────────────────────

resource "null_resource" "ml_dirs" {
  provisioner "local-exec" {
    interpreter = ["bash", "-lc"]
    command     = "mkdir -p '${path.root}/../mal/.lambda_layers' '${path.root}/../mal/build'"
  }
  triggers = { once = "1" } # run once per workspace
}

locals {
  mal_release_base = "https://github.com/${var.mal_release_owner}/${var.mal_release_repo}/releases/download/${var.mal_release_tag}"
  mal_layers_dir   = "${path.root}/../mal/.lambda_layers"
  mal_build_dir    = "${path.root}/../mal/build"

  # Public repo: no headers needed
  gh_headers = {}
}

# sk1.zip
data "http" "ml_sk1" {
  url             = "${local.mal_release_base}/sk1.zip"
  request_headers = local.gh_headers
}
resource "local_file" "ml_sk1" {
  filename       = "${local.mal_layers_dir}/sk1.zip"
  content_base64 = data.http.ml_sk1.response_body_base64
  depends_on     = [null_resource.ml_dirs]
}

# sk2.zip
data "http" "ml_sk2" {
  url             = "${local.mal_release_base}/sk2.zip"
  request_headers = local.gh_headers
}
resource "local_file" "ml_sk2" {
  filename       = "${local.mal_layers_dir}/sk2.zip"
  content_base64 = data.http.ml_sk2.response_body_base64
  depends_on     = [null_resource.ml_dirs]
}

# ml_service.zip (handler)
data "http" "ml_svc" {
  url             = "${local.mal_release_base}/ml_service.zip"
  request_headers = local.gh_headers
}
resource "local_file" "ml_svc" {
  filename       = "${local.mal_build_dir}/ml_service.zip"
  content_base64 = data.http.ml_svc.response_body_base64
  depends_on     = [null_resource.ml_dirs]
}

# ───────────────────────────────────────────────────────────────────────────────
# 1 Network
# ───────────────────────────────────────────────────────────────────────────────
module "network" {
  source     = "./modules/network"
  aws_region = var.aws_region
}

# ───────────────────────────────────────────────────────────────────────────────
# 2 API Security Group
# ───────────────────────────────────────────────────────────────────────────────
resource "aws_security_group" "api" {
  name        = "greenhouse-api-sg"
  description = "Allow HTTP inbound"
  vpc_id      = module.network.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ───────────────────────────────────────────────────────────────────────────────
# 3 Database (RDS + Secrets)
# ───────────────────────────────────────────────────────────────────────────────
module "db" {
  source                = "./modules/rds"
  db_username           = var.db_username
  db_name               = var.db_name
  vpc_id                = module.network.vpc_id
  private_subnets       = module.network.private_subnets
  api_security_group_id = aws_security_group.api.id
}

# ───────────────────────────────────────────────────────────────────────────────
# 4 Telemetry bucket
# ───────────────────────────────────────────────────────────────────────────────
module "telemetry" {
  source           = "./modules/s3-telemetry"
  telemetry_bucket = var.telemetry_bucket
}

resource "aws_s3_bucket" "ml_artifacts" {
  bucket = var.ml_artifact_bucket
}

resource "aws_s3_bucket_acl" "ml_artifacts_acl" {
  bucket = aws_s3_bucket.ml_artifacts.id
  acl    = "private"
}

# Upload the handler ZIP to S3 (downloaded above)
resource "aws_s3_object" "ml_zip" {
  bucket = aws_s3_bucket.ml_artifacts.id
  key    = var.ml_artifact_key

  source = "${path.root}/../mal/build/ml_service.zip"
  # etag   = filemd5("${path.root}/../mal/build/ml_service.zip")

  depends_on = [local_file.ml_svc]
}

# ───────────────────────────────────────────────────────────────────────────────
# 5 Static Site (S3 + CloudFront)
# ───────────────────────────────────────────────────────────────────────────────
module "static_site" {
  source      = "./modules/static-site"
  site_bucket = var.site_bucket
}

# ───────────────────────────────────────────────────────────────────────────────
# 6 Machine Learning Lambda
# ───────────────────────────────────────────────────────────────────────────────
module "lambda_ml" {
  source              = "./modules/lambda-ml"
  telemetry_bucket    = var.telemetry_bucket
  schedule_expression = "rate(1 hour)"

  # where the code ZIP is
  ml_artifact_bucket  = var.ml_artifact_bucket
  ml_artifact_key     = var.ml_artifact_key

  # ensure artifacts exist before creating Lambda & layers
  depends_on = [
    local_file.ml_sk1,
    local_file.ml_sk2,
    aws_s3_object.ml_zip
  ]
}

# ───────────────────────────────────────────────────────────────────────────────
# HTTP API → Lambda proxy for ML predict
# ───────────────────────────────────────────────────────────────────────────────

resource "aws_apigatewayv2_api" "ml_api" {
  name          = "greenhouse-ml-http"
  protocol_type = "HTTP"

  cors_configuration {
    allow_methods = ["POST"]
    allow_origins = ["*"]
    allow_headers = ["content-type"]
  }
}

resource "aws_apigatewayv2_integration" "ml" {
  api_id                 = aws_apigatewayv2_api.ml_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = module.lambda_ml.lambda_arn  # Lambda function ARN
  payload_format_version = "2.0"
  # integration_method   = "POST"  # not required for Lambda proxy on HTTP API
}

resource "aws_apigatewayv2_route" "predict" {
  api_id    = aws_apigatewayv2_api.ml_api.id
  route_key = "POST /v1/predict"
  target    = "integrations/${aws_apigatewayv2_integration.ml.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.ml_api.id
  name        = "$default"
  auto_deploy = true
}

# API Gateway is allowed to invoke the Lambda
resource "aws_lambda_permission" "allow_apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = module.lambda_ml.lambda_arn
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.ml_api.execution_arn}/*/*"
}


# ───────────────────────────────────────────────────────────────────────────────
# 7 Application Load Balancer
# ───────────────────────────────────────────────────────────────────────────────
resource "aws_lb" "api" {
  name               = "greenhouse-api-alb"
  load_balancer_type = "application"
  subnets            = module.network.public_subnets
  security_groups    = [aws_security_group.api.id]
}

# ───────────────────────────────────────────────────────────────────────────────
# 8 Target Group
# ───────────────────────────────────────────────────────────────────────────────
resource "aws_lb_target_group" "api" {
  name     = "greenhouse-api-tg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = module.network.vpc_id

  health_check {
    path                = "/health"
    matcher             = "200-399"
    interval            = 30
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

# ───────────────────────────────────────────────────────────────────────────────
# 9 Listener
# ───────────────────────────────────────────────────────────────────────────────
resource "aws_lb_listener" "api" {
  load_balancer_arn = aws_lb.api.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api.arn
  }
}

# ───────────────────────────────────────────────────────────────────────────────
# 10 ECS API Service
# ───────────────────────────────────────────────────────────────────────────────
module "api" {
  source               = "./modules/ecs-api"
  telemetry_bucket     = var.telemetry_bucket
  db_conn_string       = module.db.secret_string
  public_subnets       = module.network.public_subnets
  security_group_id    = aws_security_group.api.id
  alb_target_group_arn = aws_lb_target_group.api.arn
}
