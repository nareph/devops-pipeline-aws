# modules/alb/main.tf

# Application Load Balancer
resource "aws_lb" "this" {
  name               = "${var.environment}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_security_group_id]
  subnets            = var.public_subnet_ids

  enable_deletion_protection = false

  tags = {
    Name        = "${var.environment}-alb"
    Environment = var.environment
  }
}

# Target Group pour Blue
resource "aws_lb_target_group" "blue" {
  name        = "${var.environment}-blue-tg"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/health"
    port                = 8080
  }

  tags = {
    Name        = "${var.environment}-blue-tg"
    Environment = var.environment
    Color       = "blue"
  }
}

# Target Group pour Green
resource "aws_lb_target_group" "green" {
  name        = "${var.environment}-green-tg"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/health"
    port                = 8080
  }

  tags = {
    Name        = "${var.environment}-green-tg"
    Environment = var.environment
    Color       = "green"
  }
}

# Attacher Blue instance à sa Target Group
resource "aws_lb_target_group_attachment" "blue" {
  target_group_arn = aws_lb_target_group.blue.arn
  target_id        = var.blue_instance_id
  port             = 8080
}

# Attacher Green instance à sa Target Group
resource "aws_lb_target_group_attachment" "green" {
  target_group_arn = aws_lb_target_group.green.arn
  target_id        = var.green_instance_id
  port             = 8080
}

# Listener HTTP (port 80) - par défaut vers Blue
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.blue.arn
  }
}
