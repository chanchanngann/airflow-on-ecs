
###################################
# ALB (airflow)
###################################
resource "aws_lb_target_group" "airflow" {
  name        = "${var.name_prefix}-alb-tg-airflow"
  port        = 8080 # host port (defined at aws_ecs_task_definition)
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = module.vpc.vpc_id


  health_check {
    enabled             = true
    port                = 8080
    protocol            = "HTTP"
    
    path                = "/api/v2/monitor/health" #   https://airflow.apache.org/docs/apache-airflow/stable/administration-and-deployment/logging-monitoring/check-health.htm
    matcher             = "200"

    interval            = 30 # check every 30sec
    timeout             = 10 # timeout to wait airflow to answer

    healthy_threshold   = 2 # 2 successful checks to be considered healthy
    unhealthy_threshold = 3  # 3 failures before marked unhealthy
  }

  lifecycle {
    create_before_destroy = true
  }

}


resource "aws_lb_listener_rule" "airflow_http" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 10 # must be unique within a listener, lower number = evaluate earlier

  condition {
    host_header {
      values = [var.airflow_host_name]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.airflow.arn
  }
}
