 provider "aws" {
   region                      = var.aws_region
   access_key                  = "test"
   secret_key                  = "test"
  s3_use_path_style           = true

   endpoints {
     apigateway     = "http://localhost:4566"
     cloudformation = "http://localhost:4566"
     cloudwatch     = "http://localhost:4566"
     dynamodb       = "http://localhost:4566"
     ec2            = "http://localhost:4566"
     ecr            = "http://localhost:4566"
     ecs            = "http://localhost:4566"
     iam            = "http://localhost:4566"
     lambda         = "http://localhost:4566"
     rds            = "http://localhost:4566"
     secretsmanager = "http://localhost:4566"
     s3             = "http://localhost:4566"
     sts            = "http://localhost:4566"
   }

   # disable AWS-side validation
   skip_credentials_validation = true
   skip_requesting_account_id  = true
   skip_metadata_api_check     = true
 }
