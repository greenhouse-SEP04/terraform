variable "db_username" {
  type = string
}
variable "db_name" {
  type = string
}
variable "vpc_id" {
  type = string
}
variable "private_subnets" {
  type = list(string)
}
variable "api_security_group_id" {
  type = string
}
