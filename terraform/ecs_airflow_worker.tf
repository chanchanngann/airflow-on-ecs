###################################
# ECS task definition
###################################

resource "aws_ecs_task_definition" "airflow_worker" {
  family                   = var.airflow_worker_task_name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"

  cpu    = "1024"
  memory = "2048"

  execution_role_arn = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn      = aws_iam_role.ecs_task_role_airflow.arn

  container_definitions = jsonencode([
    {
      name      = "airflow-worker"
      image     = local.airflow_image
      essential = true

      # command = ["/worker_entry.sh"]
      command = ["celery", "worker"]
      environment = local.airflow_env
      secrets = local.airflow_secrets

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.airflow_worker.name
          awslogs-region        = var.region
          awslogs-stream-prefix = "worker"
        }
      }

    }
  ])

  tags = merge(var.common_tags,
    {
      Name = var.airflow_worker_task_name
    }
  )

}

###################################
# ECS service
###################################
resource "aws_ecs_service" "airflow_worker" {
  name            = "${var.airflow_worker_task_name}"
  cluster         = aws_ecs_cluster.airflow.id
  task_definition = aws_ecs_task_definition.airflow_worker.arn
  desired_count   = 1
  # launch_type     = "FARGATE" # remove this if you use capacity_provider_strategy
  deployment_minimum_healthy_percent = 100 # TODO: what's that
  deployment_maximum_percent         = 200 # TODO: what's that
  enable_execute_command = true # able to run: aws ecs execute-command ...

  capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    weight            = 100
  }
  
  network_configuration {
    subnets          = module.vpc.private_subnets
    security_groups  = [aws_security_group.ecs_airflow_worker_sg.id]
    assign_public_ip = false
  }

  depends_on = [
    aws_db_instance.airflow_db,
    aws_elasticache_cluster.redis,
  ]

  tags = merge(var.common_tags,
    {
      Name = "${var.airflow_worker_task_name}"
    }
  )
}

###################################
# ECS security group (worker)
###################################
resource "aws_security_group" "ecs_airflow_worker_sg" {
  name = "${var.name_prefix}-ecs-airflow-worker-sg"
  description = "managed by Terraform"
  vpc_id      = module.vpc.vpc_id
  tags = merge(var.common_tags,
    {
      Name = "${var.name_prefix}-ecs-airflow-worker-sg"
    }
  )
}

# --------------------
# ingress
# --------------------
resource "aws_vpc_security_group_ingress_rule" "worker_allow_apiserver" {
  security_group_id = aws_security_group.ecs_airflow_worker_sg.id
  description       = "allow api server" # for local served task logs if remote logging is not enabled.
  from_port = 8793
  to_port   = 8793
  ip_protocol  = "tcp"
  referenced_security_group_id = aws_security_group.ecs_airflow_apiserver_sg.id
}


# --------------------
# egress
# --------------------
# at least allow Redis 6379, RDS 5432, AWS APIs / internet via NAT (or VPC endpoints)
resource "aws_vpc_security_group_egress_rule" "worker_allow_all_traffic_ipv4" {
  security_group_id = aws_security_group.ecs_airflow_worker_sg.id
  description       = "to anywhere"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}
