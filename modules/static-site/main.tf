resource "aws_s3_bucket" "site" {
  bucket = var.site_bucket
  acl    = "public-read"
  website {
    index_document = "index.html"
    error_document = "404.html"
  }
}

resource "aws_cloudfront_distribution" "cdn" {
  origin {
    domain_name = aws_s3_bucket.site.website_endpoint
    origin_id   = "s3-site"
  }
  enabled             = true
  default_root_object = "index.html"
  default_cache_behavior {
    allowed_methods  = ["GET","HEAD"]
    cached_methods   = ["GET","HEAD"]
    target_origin_id = "s3-site"
    viewer_protocol_policy = "redirect-to-https"
  }
  viewer_certificate {
    cloudfront_default_certificate = true
  }
}
