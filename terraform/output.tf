###################################
# vpc
###################################

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  value = module.vpc.vpc_cidr_block
}

output "vpc_private_subnets" {
  value = module.vpc.private_subnets
}

output "vpc_public_subnets" {
  value = module.vpc.public_subnets
}

output "vpc_natgw_ids" {
  description = "List of NAT Gateway IDs"
  value       = module.vpc.natgw_ids
}

###################################
# S3 bucket
###################################

output "s3_bucket" {
  value = aws_s3_bucket.dbt-bucket.id
}

##################################
# RDS - airflow_db (Postgres)
##################################

output "airflow_db_postgres_endpoint_address" {
  value = aws_db_instance.airflow_db.address
}

output "airflow_db_postgres_endpoint_port" {
  value = aws_db_instance.airflow_db.port
}

output "airflow_db_postgres_db_name" {
  value = aws_db_instance.airflow_db.db_name
}

output "airflow_db_postgres_username" {
  value     = aws_db_instance.airflow_db.username
  sensitive = true
}

output "airflow_db_postgres_password" {
  value = random_string.airflow_db_password.id
  sensitive = true
}


###################################
# Bastion
###################################

output "bastion_instance_id" {
  value = try(aws_instance.bastion[0].id, null) # return value if enabled otherwise return null 
}


output "bastion_instance_public_ip" {
  value = try(aws_instance.bastion[0].public_ip, null) # return value if enabled otherwise return null 
}

output "bastion_instance_elastic_ip" {
  value = try(aws_eip.bastion[0].public_ip, null)
}

output "bastion_iam_role_arn" {
  value = aws_iam_role.instance.arn
}

###################################
# ECR
###################################

output "ecr_repository_url_airflow" {
  value = aws_ecr_repository.airflow.repository_url
}

output "ecr_repository_url_gitea" {
  value = aws_ecr_repository.gitea.repository_url
}
###################################
# ECS
###################################

output "ecs_task_execution_role_arn" {
  value = aws_iam_role.ecs_task_execution_role.arn
}

output "ecs_task_role_arn_airflow" {
  value = aws_iam_role.ecs_task_role_airflow.arn
}

output "ecs_task_role_arn_gitea" {
  value = aws_iam_role.ecs_task_role_gitea.arn
}

output "airflow_init_task_definition_id" {
  value = aws_ecs_task_definition.airflow_init.family
}


###################################
# EFS
###################################

output "efs_gitea_arn" {
  value = aws_efs_file_system.gitea.arn
}

output "efs_gitea_id" {
  value = aws_efs_file_system.gitea.id
}

output "efs_gitea_name" {
  value = aws_efs_file_system.gitea.name
}

output "efs_gitea_dns" {
  value = aws_efs_file_system.gitea.dns_name
}

output "efs_access_points" {
  description = "EFS access point IDs"
  value = {
    gitea_data = aws_efs_access_point.gitea.id
  }
}

output "kms_key_for_efs_arn" {
  description = "kms key for encryption at rest in EFS"
  value = aws_kms_key.efs.arn
}


###################################
# ALB
###################################

# output "airflow_apiserver_endpoint" {
#   value = aws_lb.alb.dns_name
# }

output "alb_endpoint" {
  value = aws_lb.alb.dns_name
}
###################################
# Redis
###################################
output "redis_endpoint" {
  value = aws_elasticache_cluster.redis.cache_nodes[0].address
}

###################################
# Cloudwatch
###################################
output "cw_log_group_airflow_init_arn" {
  value = aws_cloudwatch_log_group.airflow_init.arn
}

output "cw_log_group_airflow_apiserver_arn" {
  value = aws_cloudwatch_log_group.airflow_apiserver.arn
}

output "cw_log_group_airflow_scheduler_arn" {
  value = aws_cloudwatch_log_group.airflow_scheduler.arn
}

output "cw_log_group_airflow_worker_arn" {
  value = aws_cloudwatch_log_group.airflow_worker.arn
}

output "cw_log_group_airflow_triggerer_arn" {
  value = aws_cloudwatch_log_group.airflow_triggerer.arn
}

output "cw_log_group_airflow_dag_processor_arn" {
  value = aws_cloudwatch_log_group.airflow_dag_processor.arn
}

output "cw_log_group_gitea_arn" {
  value = aws_cloudwatch_log_group.gitea.arn
}

output "cloudwatch_log_group_redis_slow_arn" {
  value = aws_cloudwatch_log_group.redis_slow.arn
}

output "cloudwatch_log_group_redis_engine_arn" {
  value = aws_cloudwatch_log_group.redis_engine.arn
}

###################################
# security groups
###################################
output "security_group_rds_postgres_airflow_db" {
  value = aws_security_group.rds_sg.id
}

# output "security_group_airflow_instance" {
#   value = aws_security_group.airflow_instance_sg.id
# }

output "security_group_bastion_instance" {
  value = aws_security_group.bastion_sg.id
}

output "security_group_ecs_airflow_apiserver" {
  value = aws_security_group.ecs_airflow_apiserver_sg.id
}

output "security_group_ecs_airflow_scheduler" {
  value = aws_security_group.ecs_airflow_scheduler_sg.id
}

output "security_group_ecs_airflow_init" {
  value = aws_security_group.ecs_airflow_init_sg.id
}

output "security_group_ecs_airflow_triggerer" {
  value = aws_security_group.ecs_airflow_triggerer_sg.id
}

output "security_group_ecs_airflow_dag_processor" {
  value = aws_security_group.ecs_airflow_dag_processor_sg.id
}

output "security_group_ecs_gitea" {
  value = aws_security_group.ecs_gitea_sg.id
}

output "security_group_alb" {
  value = aws_security_group.alb_sg.id
}

output "security_group_redis" {
  value = aws_security_group.redis_sg.id
}

output "security_group_efs" {
  value = aws_security_group.efs_sg.id
}

