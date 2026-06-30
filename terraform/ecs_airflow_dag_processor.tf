###################################
# ECS task definition
###################################

resource "aws_ecs_task_definition" "airflow_dag_processor" {
  family                   = var.airflow_dag_processor_task_name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"

  cpu    = "256"
  memory = "512"

  execution_role_arn = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn      = aws_iam_role.ecs_task_role_airflow.arn

  container_definitions = jsonencode([
    {
      name  = "airflow-dag-processor"
      image = local.airflow_image
      # If this container dies, the whole task is considered failed.
      # one task can have multiple containers (incl. sidecars)
      essential = true

      command = ["dag-processor"] # the image ENTRYPOINT automatically prepends "airflow"
      environment = local.airflow_env
      secrets = local.airflow_secrets

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.airflow_dag_processor.name
          awslogs-region        = var.region
          awslogs-stream-prefix = "dag_processor"
        }
      }

      # health status showing on ECS task
      # healthCheck = {
      #   command = [
      #     "CMD-SHELL",
      #     "airflow jobs check --job-type DagProcessorJob --hostname $(hostname)"
      #   ]
      #   interval    = 30
      #   timeout     = 10
      #   retries     = 5
      #   startPeriod = 60
      # }
    }
  ])

  tags = merge(var.common_tags,
    {
      Name = var.airflow_dag_processor_task_name
    }
  )
}


###################################
# ECS service
###################################

resource "aws_ecs_service" "airflow_dag_processor" {
  name            = "${var.airflow_dag_processor_task_name}"
  cluster         = aws_ecs_cluster.airflow.id
  task_definition = aws_ecs_task_definition.airflow_dag_processor.arn
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
    security_groups  = [aws_security_group.ecs_airflow_dag_processor_sg.id]
    assign_public_ip = false
  }

  depends_on = [
    aws_db_instance.airflow_db,
    aws_elasticache_cluster.redis,
  ]

  tags = merge(var.common_tags,
    {
      Name = "${var.airflow_dag_processor_task_name}"
    }
  )
}

###################################
# ECS security group (dag_processor)
###################################
resource "aws_security_group" "ecs_airflow_dag_processor_sg" {
  name = "${var.name_prefix}-ecs-airflow-dag-processor-sg"
  description = "managed by Terraform"
  vpc_id      = module.vpc.vpc_id
  tags = merge(var.common_tags,
    {
      Name = "${var.name_prefix}-ecs-airflow-dag-processor-sg"
    }
  )
}

# --------------------
# ingress
# --------------------

# --------------------
# egress
# --------------------
resource "aws_vpc_security_group_egress_rule" "dag_processor_allow_all_traffic_ipv4" {
  security_group_id = aws_security_group.ecs_airflow_dag_processor_sg.id
  description       = "to anywhere"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

