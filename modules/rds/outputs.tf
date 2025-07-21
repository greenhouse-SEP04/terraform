output "secret_string_json" {
  value = module.db_secret.secret_string_json
}

output "secret_arn" {
  value = module.db_secret.secret_arn
}

output "db_instance_address" {
  value = aws_db_instance.main.address
}

output "db_instance_port" {
  value = aws_db_instance.main.port
}
