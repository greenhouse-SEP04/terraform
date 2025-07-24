provider "aws" {
  # default provider: LocalStack
  region = var.aws_region


  s3_use_path_style           = true
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true

  endpoints {
    s3     = "http://localhost:4566"
    lambda = "http://localhost:4566"
    sts    = "http://localhost:4566"
    ecs    = "http://localhost:4566"
    ecr    = "http://localhost:4566"
  }
}

provider "aws" {
  alias  = "real"
  region = var.aws_region
  # Credentials via env
}