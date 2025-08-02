resource "aws_security_group" "db" {
  name   = "greenhouse-db-sg"
  vpc_id = var.vpc_id

  ingress {
    description     = "Allow Postgres from API"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.api_security_group_id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_subnet_group" "main" {
  name       = "greenhouse-db-subnet-group"
  subnet_ids = var.private_subnets
}

resource "random_password" "db_pass" {
  length  = 16
  special = true
}

module "db_secret" {
  source  = "terraform-aws-modules/secrets-manager/aws"
  version = ">= 1.0.0"

  name = "greenhouse-db-creds"
  secret_string = jsonencode({
    username = var.db_username
    password = random_password.db_pass.result
    engine   = "postgres"
    host     = aws_db_instance.main.address
    port     = aws_db_instance.main.port
    dbname   = var.db_name
  })
}

resource "aws_db_instance" "main" {
  allocated_storage      = 20
  engine                 = "postgres"
  engine_version         = "15"
  instance_class         = "db.t3.micro"
  db_name                = var.db_name
  username               = var.db_username
  password               = random_password.db_pass.result
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.db.id]
  skip_final_snapshot    = true
}
