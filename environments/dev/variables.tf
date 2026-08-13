variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "aws_profile" {
  description = "AWS CLI profile"
  type        = string
}

variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "availability_zones" {
  description = "Availability zones for the subnets"
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
}

variable "enable_dns_support" {
  description = "Whether DNS resolution is enabled in the VPC"
  type        = bool
  default     = true
}

variable "enable_dns_hostnames" {
  description = "Whether DNS hostnames are enabled in the VPC"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Whether to use a single NAT gateway"
  type        = bool
  default     = true
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "shipops-dev"
}

variable "cluster_version" {
  description = "EKS Kubernetes version"
  type        = string
  default     = "1.30"
}

variable "endpoint_private_access" {
  description = "Whether the EKS API endpoint is private"
  type        = bool
  default     = true
}

variable "endpoint_public_access" {
  description = "Whether the EKS API endpoint is publicly accessible"
  type        = bool
  default     = false
}

variable "node_group_desired_size" {
  description = "Desired number of EKS worker nodes"
  type        = number
  default     = 2
}

variable "node_group_min_size" {
  description = "Minimum number of EKS worker nodes"
  type        = number
  default     = 1
}

variable "node_group_max_size" {
  description = "Maximum number of EKS worker nodes"
  type        = number
  default     = 3
}

variable "node_instance_types" {
  description = "EKS worker instance types"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_ami_type" {
  description = "EKS worker AMI type"
  type        = string
  default     = "AL2_x86_64"
}

variable "node_disk_size" {
  description = "Disk size for EKS worker nodes"
  type        = number
  default     = 20
}

variable "node_labels" {
  description = "Labels to assign to worker nodes"
  type        = map(string)
  default     = {}
}

variable "irsa_service_accounts" {
  description = "Service accounts for EKS Pod Identity (IRSA)"
  type = list(object({
    name        = string
    namespace   = string
    policy_arns = list(string)
  }))
  default = []
}
