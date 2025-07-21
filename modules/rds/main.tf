module "db_secret" {
  source  = "terraform-aws-modules/secrets-manager/aws"
  version = ">= 1.0.0"
  name    = "greenhouse-db-creds"
  secret_string = jsonencode({
    username = var.db_username
    password = random_password.db_pass.result
    engine   = "postgres"
    host     = aws_db_instance.main.address
    port     = aws_db_instance.main.port
    dbname   = var.db_name
  })
}

resource "random_password" "db_pass" {
  length  = 16
  special = true
}

resource "aws_db_instance" "main" {
  allocated_storage    = 20
  engine               = "postgres"
  engine_version       = "15"
  instance_class       = "db.t3.micro"
  name                 = var.db_name
  username             = var.db_username
  password             = random_password.db_pass.result
  subnet_group_name    = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.db.id]
  skip_final_snapshot  = true
}

# DB subnet group & SG omitted for brevity
