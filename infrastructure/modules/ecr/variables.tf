variable "project_name" {
  description = "Project name used for ECR resource naming"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "image_retention_count" {
  description = "Number of tagged container images retained in ECR"
  type        = number
  default     = 10
}

variable "common_tags" {
  description = "Additional tags applied to ECR"
  type        = map(string)
  default     = {}
}