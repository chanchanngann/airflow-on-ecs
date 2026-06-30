###################################
# ECS task definition
###################################

resource "aws_ecs_task_definition" "airflow_apiserver" {
  family                   = var.airflow_apiserver_task_name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"

  cpu    = "512"
  memory = "1024"

  execution_role_arn = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn      = aws_iam_role.ecs_task_role_airflow.arn

  container_definitions = jsonencode([
    {
      name  = "airflow-apiserver"
      image = local.airflow_image
      # If this container dies, the whole task is considered failed.
      # one task can have multiple containers (incl. sidecars)
      essential = true

      # command     = ["/webserver_entry.sh"]
      command = ["api-server"] # the image ENTRYPOINT automatically prepends "airflow"
      environment = local.airflow_env
      secrets = local.airflow_secrets

      portMappings = [
        {
          containerPort = 8080
          hostPort      = 8080
          protocol      = "tcp"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.airflow_apiserver.name
          awslogs-region        = var.region
          awslogs-stream-prefix = "apiserver"
        }
      }
    }
  ])

  tags = merge(var.common_tags,
    {
      Name = var.airflow_apiserver_task_name
    }
  )
}


###################################
# ECS service
###################################

resource "aws_ecs_service" "airflow_apiserver" {
  name            = "${var.airflow_apiserver_task_name}"
  cluster         = aws_ecs_cluster.airflow.id
  task_definition = aws_ecs_task_definition.airflow_apiserver.arn
  desired_count   = 1
  # launch_type     = "FARGATE" # remove this if you use capacity_provider_strategy
  health_check_grace_period_seconds = 300 # Ignore ALB health checks for first 5 minutes (dont replace the task)
  # grace period need to be LONG ENOUGH to prevent ECS from killing the task while Airflow is still booting.

  deployment_minimum_healthy_percent = 100 # TODO: what's that
  deployment_maximum_percent         = 200 # TODO: what's that
  enable_execute_command = true # able to run: aws ecs execute-command ...

  capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    weight            = 100
  }

  network_configuration {
    subnets          = module.vpc.private_subnets
    security_groups  = [aws_security_group.ecs_airflow_apiserver_sg.id]
    assign_public_ip = false
  }

  load_balancer {
    # registers the task's ENI IP and port with the LB target group.
    target_group_arn = aws_lb_target_group.airflow.arn
    container_name   = "airflow-apiserver" # must match container name in container_definitions in task_definition
    container_port   = 8080 # ECS will automatically set hostPort = containerPort for `awsvpc` network_mode.
  }

  # so that airflow worker/triggerer/dag processor/scheduler can reach api server via service discovery (connect Amazon ECS services with Cloud Map)
  service_registries {
    registry_arn = aws_service_discovery_service.airflow_api.arn
  }

  depends_on = [
    # aws_lb_listener.airflow_web_https,
    aws_lb_listener.http,
    aws_lb_listener_rule.airflow_http,
    aws_db_instance.airflow_db,
    aws_elasticache_cluster.redis,
  ]

  tags = merge(var.common_tags,
    {
      Name = "${var.airflow_apiserver_task_name}"
    }
  )
}

###################################
# ECS security group (apiserver)
###################################
resource "aws_security_group" "ecs_airflow_apiserver_sg" {
  name = "${var.name_prefix}-ecs-airflow-apiserver-sg"
  description = "managed by Terraform"
  vpc_id      = module.vpc.vpc_id
  tags = merge(var.common_tags,
    {
      Name = "${var.name_prefix}-ecs-airflow-apiserver-sg"
    }
  )
}

# --------------------
# ingress
# --------------------
resource "aws_vpc_security_group_ingress_rule" "apiserver_allow_alb" {
  security_group_id = aws_security_group.ecs_airflow_apiserver_sg.id
  description       = "allow alb on port 8080"
  from_port = 8080
  to_port   = 8080
  ip_protocol  = "tcp"
  referenced_security_group_id = aws_security_group.alb_sg.id
}

resource "aws_vpc_security_group_ingress_rule" "apiserver_allow_worker" {
  security_group_id = aws_security_group.ecs_airflow_apiserver_sg.id
  description       = "allow airflow_worker on port 8080"
  from_port = 8080
  to_port   = 8080
  ip_protocol  = "tcp"
  referenced_security_group_id = aws_security_group.ecs_airflow_worker_sg.id
}

resource "aws_vpc_security_group_ingress_rule" "apiserver_allow_scheduler" {
  security_group_id = aws_security_group.ecs_airflow_apiserver_sg.id
  description       = "allow airflow_scheduler on port 8080"
  from_port = 8080
  to_port   = 8080
  ip_protocol  = "tcp"
  referenced_security_group_id = aws_security_group.ecs_airflow_scheduler_sg.id
}

resource "aws_vpc_security_group_ingress_rule" "apiserver_allow_triggerer" {
  security_group_id = aws_security_group.ecs_airflow_apiserver_sg.id
  description       = "allow airflow_triggerer on port 8080"
  from_port = 8080
  to_port   = 8080
  ip_protocol  = "tcp"
  referenced_security_group_id = aws_security_group.ecs_airflow_triggerer_sg.id
}

resource "aws_vpc_security_group_ingress_rule" "apiserver_allow_dag_processor" {
  security_group_id = aws_security_group.ecs_airflow_apiserver_sg.id
  description       = "allow airflow_dag_processor on port 8080"
  from_port = 8080
  to_port   = 8080
  ip_protocol  = "tcp"
  referenced_security_group_id = aws_security_group.ecs_airflow_dag_processor_sg.id
}

# --------------------
# egress
# --------------------
resource "aws_vpc_security_group_egress_rule" "apiserver_allow_all_traffic_ipv4" {
  security_group_id = aws_security_group.ecs_airflow_apiserver_sg.id
  description       = "to anywhere"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

