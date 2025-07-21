variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-central-1"
}

variable "telemetry_bucket" {
  description = "Telemetry S3 bucket name"
  type        = string
}

variable "site_bucket" {
  description = "Static site S3 bucket name"
  type        = string
}

variable "db_username" {
  description = "RDS master username"
  type        = string
}

variable "db_name" {
  description = "RDS database name"
  type        = string
}

variable "ml_artifact_bucket" {
  description = "S3 bucket for ML ZIP upload"
  type        = string
}

variable "ml_artifact_key" {
  description = "Object key of ML ZIP in S3"
  type        = string
  default     = "ml_service.zip"
}
