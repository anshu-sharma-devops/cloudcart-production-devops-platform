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

variable "instance_type" {
  description = "EC2 instance type used by the CloudCart lab server"
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "Existing EC2 key-pair name"
  type        = string
  default     = "jenkins-key"
}

variable "ssh_cidr" {
  description = "Administrator public IP address allowed to use SSH"
  type        = string
  sensitive   = true

  validation {
    condition     = can(cidrnetmask(var.ssh_cidr))
    error_message = "ssh_cidr must be a valid IPv4 CIDR such as 203.0.113.10/32."
  }
}

variable "root_volume_size" {
  description = "Root EBS volume size in GiB"
  type        = number
  default     = 10
}