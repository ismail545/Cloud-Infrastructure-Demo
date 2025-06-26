# variables.tf
variable "aws_region" {
  description = "AWS region"
  default     = "eu-west-2"
}

variable "FLASK_SECRET" {
  type      = string
  sensitive = true
}

variable "OIDC_CLIENT_ID" {
  type      = string
  sensitive = true
}

variable "OIDC_CLIENT_SECRET" {
  type      = string
  sensitive = true
}