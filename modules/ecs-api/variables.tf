variable "telemetry_bucket" {
  type = string
}
variable "db_conn_string" {
  type = string
}
variable "public_subnets" {
  type = list(string)
}
variable "security_group_id" {
  type = string
}
variable "alb_target_group_arn" {
  type = string
}
