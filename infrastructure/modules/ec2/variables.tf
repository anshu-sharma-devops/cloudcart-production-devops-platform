variable "project_name" {
  description = "Project name used for AWS resource naming"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "vpc_id" {
  description = "VPC where the EC2 security group is created"
  type        = string
}

variable "subnet_id" {
  description = "Public subnet where the lab EC2 instance is deployed"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "Existing AWS EC2 key-pair name"
  type        = string
}

variable "ssh_cidr" {
  description = "CIDR allowed to connect using SSH"
  type        = string
  sensitive   = true

  validation {
    condition     = can(cidrnetmask(var.ssh_cidr))
    error_message = "ssh_cidr must be a valid IPv4 CIDR, such as 203.0.113.10/32."
  }
}

variable "root_volume_size" {
  description = "Root EBS volume size in GiB"
  type        = number
  default     = 10

  validation {
    condition     = var.root_volume_size >= 8 && var.root_volume_size <= 30
    error_message = "The root volume must be between 8 and 30 GiB."
  }
}

variable "common_tags" {
  description = "Additional tags applied to supported resources"
  type        = map(string)
  default     = {}
}