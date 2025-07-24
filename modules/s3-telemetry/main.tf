resource "aws_s3_bucket" "telemetry" {
  bucket = var.telemetry_bucket
  # no acl here
}

resource "aws_s3_bucket_acl" "telemetry_acl" {
  bucket = aws_s3_bucket.telemetry.id
  acl    = "private"
}
