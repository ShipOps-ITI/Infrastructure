variable "aws_region" {
  description = "AWS Region"
  type        = string
}

variable "aws_profile" {
  description = "AWS CLI profile"
  type        = string
}

variable "bucket_name" {
  type = string
}

variable "lock_table_name" {
  type = string
}

variable "environment" {
  type = string
}