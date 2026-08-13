variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "public_subnet_ids" {
  type = list(string)
  default = []
}

variable "cluster_version" {
  type    = string
  default = "1.31"
}

variable "endpoint_private_access" {
  type    = bool
  default = true
}

variable "endpoint_public_access" {
  type    = bool
  default = false
}

variable "node_group_desired_size" {
  type    = number
  default = 2
}

variable "node_group_min_size" {
  type    = number
  default = 1
}

variable "node_group_max_size" {
  type    = number
  default = 3
}

variable "node_instance_types" {
  type    = list(string)
  default = ["t3.medium"]
}

variable "node_ami_type" {
  type    = string
  default = "AL2_x86_64"
}

variable "node_disk_size" {
  type    = number
  default = 20
}

variable "node_labels" {
  type    = map(string)
  default = {}
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "irsa_service_accounts" {
  type = list(object({
    name        = string
    namespace   = string
    policy_arns = list(string)
  }))
  default = []
}
