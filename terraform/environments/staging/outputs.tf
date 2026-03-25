# environments/staging/outputs.tf
# Ces outputs propagent les valeurs du module VPC à la racine

output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = module.vpc.vpc_cidr
}

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = module.vpc.private_subnet_ids
}

output "public_subnet_cidrs" {
  description = "List of public subnet CIDRs"
  value       = module.vpc.public_subnet_cidrs
}

output "availability_zones" {
  description = "List of AZs used"
  value       = module.vpc.availability_zones
}

# Outputs pour les Security Groups
output "alb_security_group_id" {
  description = "ID of the ALB security group"
  value       = module.security_groups.alb_security_group_id
}

output "ec2_security_group_id" {
  description = "ID of the EC2 security group"
  value       = module.security_groups.ec2_security_group_id
}

# EC2 instances
output "blue_public_ip" {
  description = "Public IP of Blue instance"
  value       = module.ec2.blue_public_ip
}

output "green_public_ip" {
  description = "Public IP of Green instance"
  value       = module.ec2.green_public_ip
}

output "blue_private_ip" {
  description = "Private IP of Blue instance"
  value       = module.ec2.blue_private_ip
}

output "green_private_ip" {
  description = "Private IP of Green instance"
  value       = module.ec2.green_private_ip
}

# Outputs pour l'ALB
output "alb_dns_name" {
  description = "DNS name of the ALB"
  value       = module.alb.alb_dns_name
}

output "blue_target_group_arn" {
  description = "ARN of the Blue target group"
  value       = module.alb.blue_target_group_arn
}

output "green_target_group_arn" {
  description = "ARN of the Green target group"
  value       = module.alb.green_target_group_arn
}

output "alb_listener_arn" {
  description = "ARN of the ALB listener"
  value       = module.alb.alb_listener_arn
}
