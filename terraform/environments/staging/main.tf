# Configuration Terraform
terraform {
  required_version = ">= 1.4"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.37"
    }
  }
}

# Provider AWS
provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}


# Module VPC
module "vpc" {
  source = "../../modules/vpc"

  vpc_name    = "devops-staging-vpc"
  environment = var.environment
}

# Module Security Groups
module "security_groups" {
  source = "../../modules/security-groups"

  vpc_id      = module.vpc.vpc_id
  environment = var.environment
}

# Module EC2
module "ec2" {
  source = "../../modules/ec2"

  environment           = var.environment
  instance_type         = var.instance_type
  public_subnet_ids     = module.vpc.public_subnet_ids
  ec2_security_group_id = module.security_groups.ec2_security_group_id
  key_name              = var.key_name
}

# Module ALB
module "alb" {
  source = "../../modules/alb"

  environment           = var.environment
  vpc_id                = module.vpc.vpc_id
  public_subnet_ids     = module.vpc.public_subnet_ids
  alb_security_group_id = module.security_groups.alb_security_group_id
  blue_instance_id      = module.ec2.blue_instance_id
  green_instance_id     = module.ec2.green_instance_id
}
