terraform {
  required_version = ">= 1.4.0"
  backend "s3" {
    bucket = "my‑tfstate‑bucket"
    key    = "greenhouse/terraform.tfstate"
    region = "eu-central-1"
  }
}

provider "aws" {
  region = var.aws_region
}
