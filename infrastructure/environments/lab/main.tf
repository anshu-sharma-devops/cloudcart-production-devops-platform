module "vpc" {
  source = "../../modules/vpc"

  project_name = var.project_name
  environment  = var.environment
  vpc_cidr     = var.vpc_cidr

  availability_zones = var.availability_zones

  public_subnet_cidrs      = var.public_subnet_cidrs
  private_app_subnet_cidrs = var.private_app_subnet_cidrs
  database_subnet_cidrs    = var.database_subnet_cidrs

  common_tags = {
    Repository = "cloudcart-production-devops-platform"
    CostCenter = "Learning"
  }
}
module "ec2" {
  source = "../../modules/ec2"

  project_name = var.project_name
  environment  = var.environment

  vpc_id    = module.vpc.vpc_id
  subnet_id = module.vpc.public_subnet_ids[0]

  instance_type    = var.instance_type
  key_name         = var.key_name
  ssh_cidr         = var.ssh_cidr
  root_volume_size = var.root_volume_size

  common_tags = {
    Repository = "cloudcart-production-devops-platform"
    CostCenter = "Learning"
  }
}

