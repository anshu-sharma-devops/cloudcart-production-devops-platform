variable "aws_region" {
  description = "AWS region used for the CloudCart lab"
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Name used for CloudCart AWS resources"
  type        = string
  default     = "cloudcart"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "lab"
}

variable "vpc_cidr" {
  description = "CIDR block assigned to the lab VPC"
  type        = string
  default     = "10.10.0.0/16"
}

variable "availability_zones" {
  description = "Availability Zones used by the lab environment"
  type        = list(string)

  default = [
    "ap-south-1a",
    "ap-south-1b"
  ]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks assigned to public subnets"
  type        = list(string)

  default = [
    "10.10.1.0/24",
    "10.10.2.0/24"
  ]
}

variable "private_app_subnet_cidrs" {
  description = "CIDR blocks assigned to private application subnets"
  type        = list(string)

  default = [
    "10.10.11.0/24",
    "10.10.12.0/24"
  ]
}

variable "database_subnet_cidrs" {
  description = "CIDR blocks assigned to isolated database subnets"
  type        = list(string)

  default = [
    "10.10.21.0/24",
    "10.10.22.0/24"
  ]
}