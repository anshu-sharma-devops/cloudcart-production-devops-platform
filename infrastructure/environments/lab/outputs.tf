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