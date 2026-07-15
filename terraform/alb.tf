
###################################
# ALB
###################################

resource "aws_lb" "alb" {
  name               = "${var.name_prefix}-alb"
  load_balancer_type = "application"
  subnets            = module.vpc.public_subnets
  security_groups    = [aws_security_group.alb_sg.id]

  access_logs {
    bucket  = var.log_s3_bucket
    prefix  = "alb-access-logs"
    enabled = false # true # TODO: true -> need s3 bucket policy to allow access
  }

  tags = merge(var.common_tags,
    {
      Name =  "${var.name_prefix}-alb"
    }
  )

}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"

  # redirect to 443
  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }

}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 443
  protocol          = "HTTPS"

  certificate_arn   = var.airflow_cert_arn
  ssl_policy      = "ELBSecurityPolicy-TLS13-1-2-2021-06"

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "Not found"
      status_code  = "404"
    }
  }
}

resource "aws_lb_listener_certificate" "gitea" {
  listener_arn    = aws_lb_listener.https.arn
  certificate_arn = var.gitea_cert_arn
}

###################################
# ALB security group
###################################
resource "aws_security_group" "alb_sg" {
  name = "${var.name_prefix}-alb-sg"
  description = "managed by Terraform"
  vpc_id      = module.vpc.vpc_id
  tags = merge(var.common_tags,
    {
      Name = "${var.name_prefix}-alb-sg"
    }
  )
}

# --------------------
# ingress
# --------------------

resource "aws_vpc_security_group_ingress_rule" "allow_https" {
  security_group_id = aws_security_group.alb_sg.id
  description       = "HTTPS access"
  from_port = 443
  to_port   = 443
  ip_protocol  = "tcp"
  cidr_ipv4         = var.allowed_https_cidrs
}

# --------------------
# egress
# --------------------

resource "aws_vpc_security_group_egress_rule" "alb_allow_all_traffic_ipv4" {
  security_group_id = aws_security_group.alb_sg.id
  description       = "to anywhere"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

