###################################
# Cloudwatch log group
###################################

# --------------------
# airflow
# --------------------
resource "aws_cloudwatch_log_group" "airflow_apiserver" {
  name = var.cw_log_group_airflow_apiserver
  retention_in_days = 30

  tags = merge(var.common_tags,
    {
      Name = var.cw_log_group_airflow_apiserver
    }
  )
}

resource "aws_cloudwatch_log_group" "airflow_scheduler" {
  name = var.cw_log_group_airflow_scheduler
  retention_in_days = 30

  tags = merge(var.common_tags,
    {
      Name = var.cw_log_group_airflow_scheduler
    }
  )
}

resource "aws_cloudwatch_log_group" "airflow_worker" {
  name = var.cw_log_group_airflow_worker
  retention_in_days = 30

  tags = merge(var.common_tags,
    {
      Name = var.cw_log_group_airflow_worker
    }
  )
}

resource "aws_cloudwatch_log_group" "airflow_triggerer" {
  name = var.cw_log_group_airflow_triggerer
  retention_in_days = 30

  tags = merge(var.common_tags,
    {
      Name = var.cw_log_group_airflow_triggerer
    }
  )
}

resource "aws_cloudwatch_log_group" "airflow_dag_processor" {
  name = var.cw_log_group_airflow_dag_processor
  retention_in_days = 30

  tags = merge(var.common_tags,
    {
      Name = var.cw_log_group_airflow_dag_processor
    }
  )
}

resource "aws_cloudwatch_log_group" "airflow_init" {
  name = var.cw_log_group_airflow_init
  retention_in_days = 30

  tags = merge(var.common_tags,
    {
      Name = var.cw_log_group_airflow_init
    }
  )
}

# --------------------
# gitea
# --------------------
resource "aws_cloudwatch_log_group" "gitea" {
  name              = var.cw_log_group_gitea
  retention_in_days = 30

  tags = merge(var.common_tags,
    {
      Name = var.cw_log_group_gitea
    }
  )
}

# --------------------
# redis
# --------------------
resource "aws_cloudwatch_log_group" "redis_slow" {
  name              = var.cw_log_group_redis_slow
  retention_in_days = 30

  tags = merge(var.common_tags,
    {
      Name = var.cw_log_group_redis_slow
    }
  )
}

resource "aws_cloudwatch_log_group" "redis_engine" {
  name              = var.cw_log_group_redis_engine
  retention_in_days = 30

  tags = merge(var.common_tags,
    {
      Name = var.cw_log_group_redis_engine
    }
  )
}

