# ----------------------------------------------------------------------------
# Providers sections
# ----------------------------------------------------------------------------
provider "aws" {
  region = "eu-west-1"
}

# ----------------------------------------------------------------------------
# Local variables and setup
# ----------------------------------------------------------------------------
locals {
  port_load_balancer = 80
  port_instances     = 8080
}

# ----------------------------------------------------------------------------
# VPC module creation
# ----------------------------------------------------------------------------
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "3.14.0"

  name = "vpc-exercise"
  cidr = "10.0.0.0/16"

  azs             = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway = false
  enable_vpn_gateway = false

  tags = {
    Managed-by-Terraform = "true"
    Environment          = "dev"
  }
}

# ----------------------------------------------------------------------------
# Instances
# ----------------------------------------------------------------------------
data "aws_ami" "amazon_linux" {
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn2-ami-kernel-*"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  owners = ["amazon"]
}

resource "aws_instance" "this" {
  count = 2

  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"

  subnet_id              = module.vpc.private_subnets[count.index]
  vpc_security_group_ids = [aws_security_group.instance.id]

  user_data = <<-EOF
    #!/bin/bash

    echo "<h1>Hola, Terraform! Soy el servidor ${count.index}.</h1>" > index.html
    python -m SimpleHTTPServer ${local.port_instances} &
    EOF

  tags = {
    Name = "Servidor-${count.index}"
  }
}

# Create Security group for instances
resource "aws_security_group" "instance" {
  name        = "exercise-sg-instance"
  description = "Security group for exercise"

  vpc_id = module.vpc.vpc_id

  # We don't need egress rules because security groups are statefull
  ingress {
    from_port       = local.port_instances
    to_port         = local.port_instances
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }
}

# ----------------------------------------------------------------------------
# Load Balancer
# ----------------------------------------------------------------------------

resource "aws_lb" "this" {
  name            = "load-balancer-exercise"
  internal        = false
  subnets         = module.vpc.public_subnets
  security_groups = [aws_security_group.alb.id]
}

resource "aws_security_group" "alb" {
  name        = "alb-sg"
  description = "Security group for the Application Load Balancer that will allow ingress traffic to instance servers"

  vpc_id = module.vpc.vpc_id

  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    description = "Access to port ${local.port_load_balancer} from the exterior"
    from_port   = local.port_load_balancer
    to_port     = local.port_load_balancer
    protocol    = "TCP"
  }

  egress {
    cidr_blocks = ["0.0.0.0/0"]
    description = "Access to port of our servers"
    from_port   = local.port_instances
    to_port     = local.port_instances
    protocol    = "TCP"
  }
}

resource "aws_lb_target_group" "this" {
  name        = "target-group-exercise"
  port        = local.port_load_balancer
  protocol    = "HTTP"
  vpc_id      = module.vpc.vpc_id
  target_type = "instance"

  health_check {
    enabled  = true
    matcher  = "200"
    path     = "/"
    port     = local.port_instances
    protocol = "HTTP"
  }
}

resource "aws_lb_listener" "this" {
  load_balancer_arn = aws_lb.this.arn
  port              = local.port_load_balancer

  default_action {
    target_group_arn = aws_lb_target_group.this.arn
    type             = "forward"
  }
}

# ----------------------------------------------------------------------------
# Attachments to instances
# ----------------------------------------------------------------------------
resource "aws_lb_target_group_attachment" "instance_attachments" {
  for_each = toset(aws_instance.this.*.id)

  target_group_arn = aws_lb_target_group.this.arn
  target_id        = each.key
  port             = local.port_instances
}

output "lb_dns" {
  value = aws_lb.this.dns_name
}
