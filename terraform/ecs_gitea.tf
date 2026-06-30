###################################
# ECS task definition
###################################

resource "aws_ecs_task_definition" "gitea" {
  family                   = var.gitea_task_name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"

  cpu    = "256"
  memory = "512"

  execution_role_arn = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn      = aws_iam_role.ecs_task_role_gitea.arn

  volume {
    name = "gitea-data"

    efs_volume_configuration {
      file_system_id = aws_efs_file_system.gitea.id

      # use access point to avoid uid permission issue
      authorization_config {
        access_point_id = aws_efs_access_point.gitea.id
        iam             = "ENABLED" 
        # to use the Amazon ECS task IAM role defined in a task definition 
        # when mounting the Amazon EFS file system.
      }

      transit_encryption = "ENABLED"
      transit_encryption_port = 2049 # you need different port for each volume if more than 1 volume
    }
  }

  container_definitions = jsonencode([
    {
      name  = "gitea"
      image = local.gitea_image
      # If this container dies, the whole task is considered failed.
      # one task can have multiple containers (incl. sidecars)
      essential = true

      # command = [""] 
      environment = local.gitea_env
      # secrets = local.gitea_secrets

      # secrets = [
      #   {
      #     name      = "GITEA__database__PASSWD"
      #     valueFrom = "${aws_secretsmanager_secret.gitea_db_password.arn}:password::"
      #   }
      # ]

      portMappings = [
        {
          containerPort = 3000
          hostPort      = 3000
          protocol      = "tcp"
        },
        {
          containerPort = 22
          hostPort      = 22
          protocol      = "tcp"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.gitea.name
          awslogs-region        = var.region
          awslogs-stream-prefix = "gitea"
        }
      }

      mountPoints = [
        {
          sourceVolume  = "gitea-data"
          containerPath = "/data"
          readOnly      = false
        }
      ]

    }
  ])

  tags = merge(var.common_tags,
    {
      Name = var.gitea_task_name
    }
  )
}


###################################
# ECS service
###################################

resource "aws_ecs_service" "gitea" {
  name            = "${var.gitea_task_name}"
  cluster         = aws_ecs_cluster.airflow.id
  task_definition = aws_ecs_task_definition.gitea.arn
  desired_count   = 1
  # launch_type     = "FARGATE" # remove this if you use capacity_provider_strategy
  health_check_grace_period_seconds = 1200 # Ignore ALB health checks for first 5 minutes (dont replace the task)
  # grace period need to be LONG ENOUGH to prevent ECS from killing the task while GITEA is still booting.

  deployment_minimum_healthy_percent = 0 # TODO: what's that
  deployment_maximum_percent         = 200 # avoid 200 for Gitea on shared EFS because ECS may start a new Gitea task before stopping the old one.
  enable_execute_command = true # able to run: aws ecs execute-command ...

  capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    weight            = 100
  }

  network_configuration {
    subnets          = module.vpc.private_subnets
    security_groups  = [aws_security_group.ecs_gitea_sg.id]
    assign_public_ip = false
  }

  load_balancer {
    # registers the task's ENI IP and port with the LB target group.
    target_group_arn = aws_lb_target_group.gitea.arn
    container_name   = "gitea" # must match container name in container_definitions in task_definition
    container_port   = 3000 # ECS will automatically set hostPort = containerPort for `awsvpc` network_mode.
  }

  # so that airflow can reach gitea via service discovery (connect Amazon ECS services with Cloud Map)
  service_registries {
    registry_arn = aws_service_discovery_service.gitea.arn
    container_name = "gitea"
  }

  depends_on = [
    # aws_lb_listener.airflow_web_https,
    aws_lb_listener.http,
    aws_lb_listener_rule.gitea_http,
    aws_db_instance.airflow_db,
    aws_efs_mount_target.private_a, # Ensure mount targets are ready before starting tasks
    aws_efs_mount_target.private_b,
    aws_efs_mount_target.private_c
  ]

  tags = merge(var.common_tags,
    {
      Name = "${var.gitea_task_name}"
    }
  )
}

###################################
# ECS security group (apiserver)
###################################
resource "aws_security_group" "ecs_gitea_sg" {
  name = "${var.name_prefix}-ecs-gitea-sg"
  description = "managed by Terraform"
  vpc_id      = module.vpc.vpc_id
  tags = merge(var.common_tags,
    {
      Name = "${var.name_prefix}-ecs-gitea-sg"
    }
  )
}

# --------------------
# ingress
# --------------------
resource "aws_vpc_security_group_ingress_rule" "gitea_allow_alb" {
  security_group_id = aws_security_group.ecs_gitea_sg.id
  description       = "allow alb on port 3000"
  from_port = 3000
  to_port   = 3000
  ip_protocol  = "tcp"
  referenced_security_group_id = aws_security_group.alb_sg.id
}

resource "aws_vpc_security_group_ingress_rule" "gitea_allow_ssh" {
  security_group_id = aws_security_group.ecs_gitea_sg.id
  description       = "allow ssh from local"
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "gitea_allow_airflow_apiserver" {
  security_group_id = aws_security_group.ecs_gitea_sg.id
  description       = "allow airflow_apiserver on port 3000"
  from_port = 3000
  to_port   = 3000
  ip_protocol  = "tcp"
  referenced_security_group_id = aws_security_group.ecs_airflow_apiserver_sg.id
}

resource "aws_vpc_security_group_ingress_rule" "gitea_allow_airflow_scheduler" {
  security_group_id = aws_security_group.ecs_gitea_sg.id
  description       = "allow airflow_scheduler on port 3000"
  from_port = 3000
  to_port   = 3000
  ip_protocol  = "tcp"
  referenced_security_group_id = aws_security_group.ecs_airflow_scheduler_sg.id
}

resource "aws_vpc_security_group_ingress_rule" "gitea_allow_airflow_worker" {
  security_group_id = aws_security_group.ecs_gitea_sg.id
  description       = "allow airflow_worker on port 3000"
  from_port = 3000
  to_port   = 3000
  ip_protocol  = "tcp"
  referenced_security_group_id = aws_security_group.ecs_airflow_worker_sg.id
}

resource "aws_vpc_security_group_ingress_rule" "gitea_allow_airflow_triggerer" {
  security_group_id = aws_security_group.ecs_gitea_sg.id
  description       = "allow airflow_triggerer on port 3000"
  from_port = 3000
  to_port   = 3000
  ip_protocol  = "tcp"
  referenced_security_group_id = aws_security_group.ecs_airflow_triggerer_sg.id
}

resource "aws_vpc_security_group_ingress_rule" "gitea_allow_airflow_dag_processor" {
  security_group_id = aws_security_group.ecs_gitea_sg.id
  description       = "allow airflow_dag_processor on port 3000"
  from_port = 3000
  to_port   = 3000
  ip_protocol  = "tcp"
  referenced_security_group_id = aws_security_group.ecs_airflow_dag_processor_sg.id
}

# --------------------
# egress
# --------------------
resource "aws_vpc_security_group_egress_rule" "gitea_allow_all_traffic_ipv4" {
  security_group_id = aws_security_group.ecs_gitea_sg.id
  description       = "to anywhere"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

