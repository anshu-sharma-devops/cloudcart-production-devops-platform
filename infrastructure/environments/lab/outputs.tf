output "vpc_id" {
  description = "ID of the CloudCart lab VPC"
  value       = module.vpc.vpc_id
}

output "vpc_cidr" {
  description = "CIDR block assigned to the CloudCart lab VPC"
  value       = module.vpc.vpc_cidr
}

output "internet_gateway_id" {
  description = "ID of the CloudCart Internet Gateway"
  value       = module.vpc.internet_gateway_id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = module.vpc.public_subnet_ids
}

output "private_app_subnet_ids" {
  description = "IDs of the private application subnets"
  value       = module.vpc.private_app_subnet_ids
}

output "database_subnet_ids" {
  description = "IDs of the isolated database subnets"
  value       = module.vpc.database_subnet_ids
}

output "public_route_table_id" {
  description = "ID of the public route table"
  value       = module.vpc.public_route_table_id
}

output "private_app_route_table_id" {
  description = "ID of the private application route table"
  value       = module.vpc.private_app_route_table_id
}

output "database_route_table_id" {
  description = "ID of the database route table"
  value       = module.vpc.database_route_table_id
}
output "app_instance_id" {
  description = "ID of the CloudCart lab application server"
  value       = module.ec2.instance_id
}

output "app_public_ip" {
  description = "Public IP address of the application server"
  value       = module.ec2.public_ip
}

output "app_private_ip" {
  description = "Private IP address of the application server"
  value       = module.ec2.private_ip
}

output "app_security_group_id" {
  description = "ID of the application security group"
  value       = module.ec2.security_group_id
}

output "app_ami_id" {
  description = "Ubuntu AMI used by the application server"
  value       = module.ec2.ami_id
}

output "app_ssh_command" {
  description = "SSH command for connecting to the application server"
  value       = "ssh -i ~/.ssh/jenkins-key.pem ubuntu@${module.ec2.public_ip}"
}

output "app_url" {
  description = "CloudCart application URL"
  value       = "http://${module.ec2.public_ip}"
}