
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

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "Unknown host"
      status_code  = "404"
    }
  }
  # EVERYTHING arriving on port 80 goes to Airflow
  # hide this part if redirect to 443
  # default_action {
  #   type             = "forward"
  #   target_group_arn = aws_lb_target_group.airflow.arn
  # }

  # redirect to 443
  # default_action {
  #   type = "redirect"

  #   redirect {
  #     port        = "443"
  #     protocol    = "HTTPS"
  #     status_code = "HTTP_301"
  #   }
  # }
}

# resource "aws_lb_listener" "airflow_web_https" {
#   load_balancer_arn = aws_lb.alb.arn
#   port              = 443
#   protocol          = "HTTPS"
#   certificate_arn   = aws_acm_certificate.airflow_cert.arn

#   default_action {
#     type             = "forward"
#     target_group_arn = aws_lb_target_group.airflow.arn
#   }
# }

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
resource "aws_vpc_security_group_ingress_rule" "alb_allow_http" {
  security_group_id = aws_security_group.alb_sg.id
  description       = "HTTP access"
  from_port = 80
  to_port   = 80
  ip_protocol  = "tcp"
  cidr_ipv4         = "0.0.0.0/0"

}

# resource "aws_vpc_security_group_ingress_rule" "allow_https" {
#   security_group_id = aws_security_group.alb_sg.id
#   description       = "HTTPS access"
#   from_port = 443
#   to_port   = 443
#   ip_protocol  = "tcp"
#   cidr_ipv4         = "0.0.0.0/0"
# }

# --------------------
# egress
# --------------------

resource "aws_vpc_security_group_egress_rule" "alb_allow_all_traffic_ipv4" {
  security_group_id = aws_security_group.alb_sg.id
  description       = "to anywhere"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

