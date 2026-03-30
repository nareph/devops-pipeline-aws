# modules/security-groups/main.tf

resource "aws_security_group" "alb" {
  name        = "${var.environment}-alb-sg"
  description = "Security group for ALB - allows HTTP/HTTPS from internet"
  vpc_id      = var.vpc_id

  tags = {
    Name        = "${var.environment}-alb-sg"
    Environment = var.environment
  }
}

# HTTP depuis internet
resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
  description       = "Allow HTTP from internet"
}

# HTTPS depuis internet (pour plus tard)
resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  security_group_id = aws_security_group.alb.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  ip_protocol       = "tcp"
  to_port           = 443
  description       = "Allow HTTPS from internet"
}

# Sortie : tout autoriser
resource "aws_vpc_security_group_egress_rule" "alb_egress" {
  security_group_id = aws_security_group.alb.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "Allow all outbound traffic"
}

# -----------------------------------------------------------------------------
# Security Group pour les instances EC2
# -----------------------------------------------------------------------------
resource "aws_security_group" "ec2" {
  name        = "${var.environment}-ec2-sg"
  description = "Security group for EC2 instances - allows traffic from ALB"
  vpc_id      = var.vpc_id

  tags = {
    Name        = "${var.environment}-ec2-sg"
    Environment = var.environment
  }
}

# Port applicatif (8080) depuis l'ALB uniquement
resource "aws_vpc_security_group_ingress_rule" "ec2_app" {
  security_group_id            = aws_security_group.ec2.id
  referenced_security_group_id = aws_security_group.alb.id
  from_port                    = 8080
  ip_protocol                  = "tcp"
  to_port                      = 8080
  description                  = "Allow traffic from ALB on port 8080"
}

# ⚠️ Règle SSH SUPPRIMÉE - plus d'accès SSH direct
# Les connexions se feront via AWS Session Manager uniquement

# Sortie : tout autoriser
resource "aws_vpc_security_group_egress_rule" "ec2_egress" {
  security_group_id = aws_security_group.ec2.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "Allow all outbound traffic"
}
