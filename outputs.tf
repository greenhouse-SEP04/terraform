output "api_endpoint" {
  description = "API ALB DNS name"
  value       = aws_lb.api.dns_name
}

output "website_url" {
  description = "Static site CloudFront domain"
  value       = module.static_site.cdn_domain_name
}

output "ml_lambda_arn" {
  description = "ML Lambda function ARN"
  value       = module.lambda_ml.lambda_arn
}

output "db_secret_arn" {
  description = "ARN of Secrets Manager secret for RDS credentials"
  value       = module.db.secret_arn
}
