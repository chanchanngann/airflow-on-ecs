###################################
# ECS cluster
###################################

resource "aws_ecs_cluster" "airflow" {
  name = var.ecs_cluster_name

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = merge(var.common_tags,
    {
      Name = var.ecs_cluster_name
    }
  )
}


###################################
# ECS IAM task execution role
###################################

# ecs infra permissions
resource "aws_iam_role" "ecs_task_execution_role" {
  name = var.ecs_task_execution_role

  assume_role_policy = data.aws_iam_policy_document.ecs_assume_role.json

  tags = merge(var.common_tags,
    {
      Name = var.ecs_task_execution_role
    }
  )

}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role = aws_iam_role.ecs_task_execution_role.name

  # allow ecs to pull images from ecr & send logs to cloudwatch
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"

}

resource "aws_iam_role_policy" "access_secret_manager" {
  role = aws_iam_role.ecs_task_execution_role.id
  name = "access-secret-manager"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = [
          aws_secretsmanager_secret.airflow_admin.arn,
          aws_secretsmanager_secret.airflow_db.arn,
          aws_secretsmanager_secret.airflow_fernet_key.arn,
          aws_secretsmanager_secret.gitea_db_password.arn,
          aws_secretsmanager_secret.airflow_api_secret_key.arn,
          aws_secretsmanager_secret.airflow_api_auth_jwt_secret.arn
        ]
      }
    ]
  })
}


###################################
# ECS IAM task role (airflow)
###################################

# for ecs task (airflow permissions)
resource "aws_iam_role" "ecs_task_role_airflow" {
  name = var.ecs_task_role_airflow

  assume_role_policy = data.aws_iam_policy_document.ecs_assume_role.json

  tags = merge(var.common_tags,
    {
      Name = var.ecs_task_role_airflow
    }
  )

}

resource "aws_iam_role_policy_attachment" "access_ssm_airflow" {
  role = aws_iam_role.ecs_task_role_airflow.name

  # to execute "aws ecs execute-command"
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"

}

resource "aws_iam_role_policy" "access_s3_airflow" {
  role = aws_iam_role.ecs_task_role_airflow.id
  name = "airflow-access-s3"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.log_s3_bucket}",
          "arn:aws:s3:::${var.dbt_s3_bucket}",
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = [
          "arn:aws:s3:::${var.log_s3_bucket}",
          "arn:aws:s3:::${var.dbt_s3_bucket}",
          "arn:aws:s3:::${var.log_s3_bucket}/*",
          "arn:aws:s3:::${var.dbt_s3_bucket}/*",
        ]
      }
    ]
  })
}


###################################
# ECS IAM task role (gitea)
###################################

# for ecs task (gitea permissions)
resource "aws_iam_role" "ecs_task_role_gitea" {
  name = var.ecs_task_role_gitea

  assume_role_policy = data.aws_iam_policy_document.ecs_assume_role.json

  tags = merge(var.common_tags,
    {
      Name = var.ecs_task_role_gitea
    }
  )
}

resource "aws_iam_role_policy_attachment" "access_ssm_gitea" {
  role = aws_iam_role.ecs_task_role_gitea.name

  # to execute "aws ecs execute-command"
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy" "access_s3_gitea" {
  role = aws_iam_role.ecs_task_role_gitea.id
  name = "access-s3-gitea"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.log_s3_bucket}",
          "arn:aws:s3:::${var.dbt_s3_bucket}",
          "arn:aws:s3:::${var.log_s3_bucket}/*",
          "arn:aws:s3:::${var.dbt_s3_bucket}/*",
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_access_efs" {
  role       = aws_iam_role.ecs_task_role_gitea.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonElasticFileSystemClientReadWriteAccess"
}
