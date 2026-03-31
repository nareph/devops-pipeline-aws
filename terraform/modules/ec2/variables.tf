# modules/ec2/variables.tf

variable "environment" {
  description = "Environment name (staging/production)"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs"
  type        = list(string)
}

variable "ec2_security_group_id" {
  description = "ID of the EC2 security group"
  type        = string
}

variable "key_name" {
  description = "Name of the SSH key pair"
  type        = string
  default     = "devops-staging-key"
}

variable "blue_instance_name" {
  description = "Name tag for Blue instance"
  type        = string
  default     = "blue"
}

variable "green_instance_name" {
  description = "Name tag for Green instance"
  type        = string
  default     = "green"
}
