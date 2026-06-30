###################################
# ECS task definition
###################################

resource "aws_ecs_task_definition" "airflow_init" {

  family                   = var.airflow_init_task_name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"

  cpu    = "256"
  memory = "512"

  execution_role_arn = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn      = aws_iam_role.ecs_task_role_airflow.arn

  container_definitions = jsonencode([
    {
      name  = "airflow-init"
      image = local.airflow_image
      # If this container dies, the whole task is considered failed.
      # one task can have multiple containers (incl. sidecars)
      essential = true

      entryPoint = ["/airflow_init.sh"]
      environment = local.airflow_env
      secrets = local.airflow_secrets

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.airflow_init.name
          awslogs-region        = var.region
          awslogs-stream-prefix = "init"
        }
      }
    }
  ])

  depends_on = [
    aws_security_group.ecs_airflow_init_sg
  ]

  tags = merge(var.common_tags,
    {
      Name = var.airflow_init_task_name
    }
  )
}


###################################
# ECS service
###################################

# one-off task does not need service

###################################
# ECS security group (init)
###################################
resource "aws_security_group" "ecs_airflow_init_sg" {
  name = "${var.name_prefix}-ecs-airflow-init-sg"
  description = "managed by Terraform"
  vpc_id      = module.vpc.vpc_id
  tags = merge(var.common_tags,
    {
      Name = "${var.name_prefix}-ecs-airflow-init-sg"
    }
  )
}

# --------------------
# ingress
# --------------------


# --------------------
# egress
# --------------------
resource "aws_vpc_security_group_egress_rule" "init_allow_all_traffic_ipv4" {
  security_group_id = aws_security_group.ecs_airflow_init_sg.id
  description       = "to anywhere"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}
