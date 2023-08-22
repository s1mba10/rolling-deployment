provider "aws" {
  region = "eu-north-1"
}
#-------------------------------------------------
data "aws_availability_zones" "zones" {}


data "aws_ami" "latest_amazon_linux" {
  owners      = ["amazon"]
  most_recent = true
  filter {
    name   = "name"
    values = ["al2023-ami-2023.1.*.0-kernel-6.1-x86_64"]
  }
}

#-------------------------------------------------
resource "aws_default_vpc" "default" {}


resource "aws_default_subnet" "az1" {
  availability_zone = data.aws_availability_zones.zones.names[0]
}


resource "aws_default_subnet" "az2" {
  availability_zone = data.aws_availability_zones.zones.names[1]
}
#-------------------------------------------------
resource "aws_security_group" "sg" {
  name        = "RollingDeploymentSG"
  description = "Security group for webserver with 80, 443 ports exposed"
  dynamic "ingress" {
    for_each = ["80", "443"]
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name  = "Rolling Deployment SG"
    Owner = "Ivan Ivanov"
  }
}
#-------------------------------------------------
resource "aws_launch_template" "lch_template" {
  name = "WebServerLaunchTemplate"

  image_id               = data.aws_ami.latest_amazon_linux.id
  vpc_security_group_ids = [aws_security_group.sg.id]
  instance_type          = "t3.micro"
  user_data              = filebase64("${path.module}/user_data.sh")
}

resource "aws_autoscaling_group" "asg" {
  name                = "WebServer-Highly-Available-ASG-Ver-${aws_launch_template.lch_template.latest_version}"
  min_size            = 2
  max_size            = 2
  min_elb_capacity    = 2
  health_check_type   = "ELB"
  vpc_zone_identifier = [aws_default_subnet.az1.id, aws_default_subnet.az2.id]
  target_group_arns   = [aws_lb_target_group.web.arn] #!!!

  launch_template {
    id      = aws_launch_template.lch_template.id
    version = aws_launch_template.lch_template.latest_version
  }

  dynamic "tag" {
    for_each = {
      Name   = "WebServer in ASG-v${aws_launch_template.lch_template.latest_version}"
      TAGKEY = "TAGVALUE"
    }
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }
  lifecycle {
    create_before_destroy = true
  }
}
#-------------------------------------------------------------------------------
resource "aws_lb" "lb" {
  name               = "WebServer-HighlyAvailable-ALB"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.sg.id]
  subnets            = [aws_default_subnet.az1.id, aws_default_subnet.az2.id]
}

resource "aws_lb_target_group" "web" {
  name                 = "WebServer-TargetGroup"
  vpc_id               = aws_default_vpc.default.id
  port                 = 80
  protocol             = "HTTP"
  deregistration_delay = 10 # seconds
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}
#-------------------------------------------------------------------------------
output "url" {
  value = aws_lb.lb.dns_name
}


