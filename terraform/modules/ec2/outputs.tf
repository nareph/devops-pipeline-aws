# modules/ec2/outputs.tf

output "blue_instance_id" {
  description = "ID of Blue instance"
  value       = aws_instance.blue.id
}

output "green_instance_id" {
  description = "ID of Green instance"
  value       = aws_instance.green.id
}

output "blue_public_ip" {
  description = "Public IP of Blue instance"
  value       = aws_instance.blue.public_ip
}

output "green_public_ip" {
  description = "Public IP of Green instance"
  value       = aws_instance.green.public_ip
}

output "blue_private_ip" {
  description = "Private IP of Blue instance"
  value       = aws_instance.blue.private_ip
}

output "green_private_ip" {
  description = "Private IP of Green instance"
  value       = aws_instance.green.private_ip
}
