# 1 Network
module "network" {
  source = "./modules/network"
  aws_region = var.aws_region
}

# 2 API Security Group
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

# 3 Database (RDS + Secrets)
module "db" {
  source                = "./modules/rds"
  db_username           = var.db_username
  db_name               = var.db_name
  vpc_id                = module.network.vpc_id
  private_subnets       = module.network.private_subnets
  api_security_group_id = aws_security_group.api.id
}

# 4 Telemetry bucket
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

data "http" "mal_zip" {
  url             = "https://github.com/greenhouse-SEP04/mal/releases/download/${var.mal_tag}/ml_service.zip"
  request_headers = { Accept = "application/octet-stream" }
}

resource "local_file" "mal_zip" {
  filename = "${path.module}/.mal.zip"
  content  = data.http.mal_zip.body
}

resource "aws_s3_object" "ml_zip" {
  bucket = aws_s3_bucket.ml_artifacts.id
  key    = var.ml_artifact_key
  source = local_file.mal_zip.filename
  etag   = filemd5(local_file.mal_zip.filename)
}


# 5 Static Site (S3 + CloudFront)
module "static_site" {
  source      = "./modules/static-site"
  site_bucket = var.site_bucket
}

# 6 Machine Learning Lambda
module "lambda_ml" {
  source           = "./modules/lambda-ml"
  ml_s3_bucket     = var.ml_artifact_bucket
  ml_s3_key        = var.ml_artifact_key
  telemetry_bucket = var.telemetry_bucket
}

# 7 Application Load Balancer
resource "aws_lb" "api" {
  name               = "greenhouse-api-alb"
  load_balancer_type = "application"
  subnets            = module.network.public_subnets
  security_groups    = [aws_security_group.api.id]
}

# 8 Target Group
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

# 9 Listener
resource "aws_lb_listener" "api" {
  load_balancer_arn = aws_lb.api.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api.arn
  }
}

# 10 ECS API Service
module "api" {
  source               = "./modules/ecs-api"
  telemetry_bucket     = var.telemetry_bucket
  db_conn_string       = module.db.secret_string
  public_subnets       = module.network.public_subnets
  security_group_id    = aws_security_group.api.id
  alb_target_group_arn = aws_lb_target_group.api.arn
}
