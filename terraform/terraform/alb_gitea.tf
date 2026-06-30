
# ###################################
# # ALB (gitea)
# ###################################

resource "aws_lb_target_group" "gitea" {
  name        = "${var.name_prefix}-alb-tg-gitea"
  port        = 3000 # host port (defined at aws_ecs_task_definition)
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = module.vpc.vpc_id

  health_check {
    enabled             = true
    path                = "/api/healthz"
    matcher             = "200" # TODO: may not return 200 if redirect (maybe 399?)

    interval            = 30 # check every 30sec
    timeout             = 10 # timeout to wait airflow to answer

    healthy_threshold   = 2 # 2 successful checks to be considered healthy
    unhealthy_threshold = 3  # 3 failures before marked unhealthy
  }

  lifecycle {
    create_before_destroy = true
  }

}

resource "aws_lb_listener_rule" "gitea_http" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 20 # must be unique within a listener, lower number = evaluate earlier

  condition {
    host_header {
      values = [var.gitea_host_name]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.gitea.arn
  }
}
