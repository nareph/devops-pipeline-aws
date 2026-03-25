# modules/ec2/main.tf

# Récupérer la dernière AMI Ubuntu 24.04
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

# Instance Blue
resource "aws_instance" "blue" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type # t3.micro
  subnet_id              = var.public_subnet_ids[0]
  vpc_security_group_ids = [var.ec2_security_group_id]
  key_name               = var.key_name

  associate_public_ip_address = true

  user_data = <<-EOF
    #!/bin/bash
    echo "Blue instance - $(date)" > /var/www/index.html
    # Plus tard: installation de l'application Rust
  EOF

  tags = {
    Name        = "${var.environment}-${var.blue_instance_name}"
    Environment = var.environment
    Color       = "blue"
  }
}

# Instance Green
resource "aws_instance" "green" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type # t3.micro
  subnet_id              = var.public_subnet_ids[1]
  vpc_security_group_ids = [var.ec2_security_group_id]
  key_name               = var.key_name

  associate_public_ip_address = true

  user_data = <<-EOF
    #!/bin/bash
    echo "Green instance - $(date)" > /var/www/index.html
    # Plus tard: installation de l'application Rust
  EOF

  tags = {
    Name        = "${var.environment}-${var.green_instance_name}"
    Environment = var.environment
    Color       = "green"
  }
}
