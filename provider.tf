 provider "aws" {
   region                      = var.aws_region
   access_key                  = "test"
   secret_key                  = "test"
   s3_use_path_style           = true

   endpoints {
     apigateway     = "http://localhost:4566"
     cloudformation = "http://localhost:4566"
     cloudwatch     = "http://localhost:4566"
    events         = "http://localhost:4566"    # ← EventBridge / CloudWatch Events
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
    elb            = "http://localhost:4566"    # ← Classic ELB (if you ever use it)
    elbv2          = "http://localhost:4566"    # ← Application/Network Load Balancers
    cloudfront     = "http://localhost:4566"    # ← CloudFront distributions
   }

   # disable AWS-side validation
   skip_credentials_validation = true
   skip_region_validation      = true
   skip_requesting_account_id  = true
   skip_metadata_api_check     = true
 }
