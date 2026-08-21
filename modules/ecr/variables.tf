variable "project_name" {
  description = "Project name prefix for repository names"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "repository_names" {
  description = "List of repository names to create (will be prefixed with project_name)"
  type        = list(string)
}

variable "image_tag_mutability" {
  description = "Image tag mutability: MUTABLE or IMMUTABLE"
  type        = string
  default     = "MUTABLE"
}

variable "scan_on_push" {
  description = "Enable image scanning on push"
  type        = bool
  default     = true
}

variable "max_image_count" {
  description = "Maximum number of images to retain per repository"
  type        = number
  default     = 10
}
