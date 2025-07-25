resource "aws_ecr_repository" "api" {
  name = "greenhouse-api"
}

data "aws_iam_policy_document" "ecs_task_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_task" {
  name               = "greenhouse-ecs-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume.json
}

resource "aws_ecs_cluster" "main" {
  name = "greenhouse-cluster"
}

resource "aws_ecs_task_definition" "api" {
  family                   = "greenhouse-api"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"
  memory                   = "1024"
  network_mode             = "awsvpc"
  execution_role_arn       = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([{
    name      = "api"
    image     = "${aws_ecr_repository.api.repository_url}:latest"
    portMappings = [{
      containerPort = 8080
    }]
    environment = [
      { name = "AWS__TelemetryBucket",                 value = var.telemetry_bucket },
      { name = "ConnectionStrings__DefaultConnection", value = var.db_conn_string }
    ]
  }])
}

resource "aws_ecs_service" "api" {
  name            = "greenhouse-api"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.api.arn
  desired_count   = 2
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = var.public_subnets
    security_groups = [var.security_group_id]
  }

  load_balancer {
    target_group_arn = var.alb_target_group_arn
    container_name   = "api"
    container_port   = 8080
  }
}
