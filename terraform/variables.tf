####################################
# Common
####################################

variable "name_prefix" {
  type = string
}

variable "region" {
  description = "AWS region to deploy resources"
  type        = string
}

variable "common_tags" {
  type = map(any)
}

variable "ec2_key_name" {
  type = string
}

variable "enable_bastion" {
  type    = bool
  default = false
}

variable "enable_airflow_server" {
  type    = bool
  default = false
}

variable "allowed_https_cidrs" {
  type = string
}



###################################
# networking
###################################
variable "vpc_name" {
  type = string
}

variable "vpc_cidr" {
  type = string
}


variable "vpc_public_subnets" {
  type = list(any)
}


variable "vpc_private_subnets" {
  type = list(any)
}

variable "vpc_azs" {
  type = list(any)
}

###################################
# S3 bucket
###################################

variable "dbt_s3_bucket" {
  type        = string
  description = "S3 bucket for data storage"
}

variable "log_s3_bucket" {
  type        = string
  description = "S3 bucket for log storage"
}

###################################
# Instance type
###################################

variable "bastion_instance_type" {
  type = string
}

variable "airflow_instance_type" {
  type = string
}

variable "redis_node_type" {
  type = string
}

variable "rds_instance_class" {
  type = string
}

###################################
# DB username
###################################

variable "postgres_username" {
  type = string
}

variable "snowflake_username" {
  type = string
}

variable "redis_username" {
  type = string
}

###################################
# ECR
###################################

variable "ecr_repo_name" {
  type = string
}


variable "ecr_repo_name_gitea" {
  type = string
}


###################################
# ECS
###################################

variable "ecs_cluster_name" {
  type = string
}

variable "ecs_task_execution_role" {
  type = string
}

variable "ecs_task_role_airflow" {
  type = string
}

variable "ecs_task_role_gitea" {
  type = string
}
###################################
# Airflow
###################################
variable "airflow_base_url" {
  type = string
}

variable "airflow_host_name" {
  type = string
}

variable "airflow_db_url" {
  type = string
}

variable "airflow_broker_url" {
  type = string
}

variable "airflow_apiserver_task_name" {
  type = string
}

variable "airflow_scheduler_task_name" {
  type = string
}

variable "airflow_worker_task_name" {
  type = string
}

variable "airflow_init_task_name" {
  type = string
}

variable "airflow_dag_processor_task_name" {
  type = string
}

variable "airflow_triggerer_task_name" {
  type = string
}

variable "airflow_fernet_key" {
  type = string
  sensitive = true
}

variable "airflow_api_secret_key" {
  type = string
  sensitive = true
}

variable "airflow_api_auth_jwt_secret" {
  type = string
  sensitive = true
}

variable "airflow_admin_password" {
  type = string
  sensitive = true
}

variable "airflow_image_tag" {
  type = string
}

variable "airflow_execution_api_server_url" {
  type = string
}


###################################
# Gitea
###################################
variable "gitea_task_name" {
  type = string
}

variable "gitea_image_tag" {
  type = string
}

variable "gitea_host_name" {
  type = string
}


# variable "gitea_root_url" {
#   type = string
# }

variable "gitea_repo_url_for_git_dag_bundle" {
  type = string
}


###################################
# ALB
###################################

# variable "alb_name_airflow_apiserver" {
#   type = string
# }

# variable "alb_name_gitea" {
#   type = string
# }

variable "airflow_cert_arn" {
  type = string
}

variable "gitea_cert_arn" {
  type = string
}
###################################
# Cloudwatch
###################################
variable "cw_log_group_airflow_init" {
  type = string
}

variable "cw_log_group_airflow_apiserver" {
  type = string
}

variable "cw_log_group_airflow_scheduler" {
  type = string
}

variable "cw_log_group_airflow_worker" {
  type = string
}

variable "cw_log_group_airflow_triggerer" {
  type = string
}

variable "cw_log_group_airflow_dag_processor" {
  type = string
}

variable "cw_log_group_redis_slow" {
  type = string
}

variable "cw_log_group_redis_engine" {
  type = string
}

variable "cw_log_group_gitea" {
  type = string
}

