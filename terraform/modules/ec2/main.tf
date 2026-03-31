# modules/ec2/main.tf

# IAM Role pour Session Manager
resource "aws_iam_role" "ssm_role" {
  name = "${var.environment}-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.environment}-ssm-role"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "ssm_policy" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm_profile" {
  name = "${var.environment}-ssm-profile"
  role = aws_iam_role.ssm_role.name

  tags = {
    Name        = "${var.environment}-ssm-profile"
    Environment = var.environment
  }
}

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

  owners = ["099720109477"]
}

# Instance Blue
resource "aws_instance" "blue" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = var.public_subnet_ids[0]
  vpc_security_group_ids = [var.ec2_security_group_id]

  # ✅ Ajout du profil IAM pour Session Manager
  iam_instance_profile = aws_iam_instance_profile.ssm_profile.name

  associate_public_ip_address = true

  user_data = <<-EOF
    #!/bin/bash
    # Installer l'agent SSM (déjà présent sur les AMIs Ubuntu)
    systemctl enable amazon-ssm-agent
    systemctl start amazon-ssm-agent
    echo "Blue instance - $(date)" > /var/www/index.html
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
  instance_type          = var.instance_type
  subnet_id              = var.public_subnet_ids[1]
  vpc_security_group_ids = [var.ec2_security_group_id]

  # ✅ Ajout du profil IAM pour Session Manager
  iam_instance_profile = aws_iam_instance_profile.ssm_profile.name

  associate_public_ip_address = true

  user_data = <<-EOF
    #!/bin/bash
    systemctl enable amazon-ssm-agent
    systemctl start amazon-ssm-agent
    echo "Green instance - $(date)" > /var/www/index.html
  EOF

  tags = {
    Name        = "${var.environment}-${var.green_instance_name}"
    Environment = var.environment
    Color       = "green"
  }
}
