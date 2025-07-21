resource "aws_s3_bucket" "telemetry" {
  bucket = var.telemetry_bucket
  acl    = "private"
}
