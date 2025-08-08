# provider.tf   (single provider block – no more commenting!)
provider "aws" {
  region                  = var.aws_region

  # use dummy creds only when we’re on LocalStack
  access_key              = var.use_localstack ? "test" : null
  secret_key              = var.use_localstack ? "test" : null
  s3_use_path_style       = var.use_localstack

  # LocalStack endpoints (empty map = normal AWS URLs)
  endpoints               = var.use_localstack ? local.localstack_endpoints : {}

  # Skip SDK checks only for LocalStack
  skip_credentials_validation = var.use_localstack
  skip_region_validation      = var.use_localstack
  skip_requesting_account_id  = var.use_localstack
  skip_metadata_api_check     = var.use_localstack
}
