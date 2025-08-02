variable "telemetry_bucket" {
  type = string
}

variable "schedule_expression" {
  type    = string
  default = "rate(1 hour)"
}

# NEW: where the function ZIP lives
variable "ml_artifact_bucket" {
  type = string
}
variable "ml_artifact_key" {
  type = string
}
