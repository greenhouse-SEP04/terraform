terraform {
  required_version = ">= 1.4.0"

  backend "local" {
    path = "terraform.tfstate"
  }
}
