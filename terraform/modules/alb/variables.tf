# modules/alb/variables.tf

variable "environment" {
  description = "Environment name (staging/production)"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs for ALB"
  type        = list(string)
}

variable "alb_security_group_id" {
  description = "ID of the ALB security group"
  type        = string
}

variable "blue_instance_id" {
  description = "ID of the Blue EC2 instance"
  type        = string
}

variable "green_instance_id" {
  description = "ID of the Green EC2 instance"
  type        = string
}
