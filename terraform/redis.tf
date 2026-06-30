###################################
# Redis subnets
###################################

resource "aws_elasticache_subnet_group" "redis" {
  name       = "${var.name_prefix}-redis-subnet-group"
  subnet_ids = module.vpc.private_subnets
}

###################################
# Redis cluster
###################################

resource "aws_elasticache_cluster" "redis" {
  cluster_id           = "${var.name_prefix}-redis"
  engine               = "redis"
  engine_version       = "7.1" # https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/engine-versions.html
  node_type            = var.redis_node_type 
  num_cache_nodes      = 1
  port = 6379
  parameter_group_name = "default.redis7" # need to match major engine version

  subnet_group_name  = aws_elasticache_subnet_group.redis.name
  security_group_ids = [aws_security_group.redis_sg.id]

  log_delivery_configuration {
    destination      = aws_cloudwatch_log_group.redis_slow.name
    destination_type = "cloudwatch-logs"
    log_format       = "json"
    log_type         = "slow-log"
  }
  
  log_delivery_configuration {
    destination      = aws_cloudwatch_log_group.redis_engine.name
    destination_type = "cloudwatch-logs"
    log_format       = "json"
    log_type         = "engine-log"
  }

  tags = merge(var.common_tags,
    {
      Name = "${var.name_prefix}-redis"
    }
  )

}


###################################
# Redis security group
###################################
resource "aws_security_group" "redis_sg" {
  name = "${var.name_prefix}-redis-sg"
  description = "allow ecs inbound traffic and all outbound traffic"
  vpc_id      = module.vpc.vpc_id
  tags = merge(var.common_tags,
    {
      Name = "${var.name_prefix}-redis-sg"
    }
  )
}

# --------------------
# ingress
# --------------------
resource "aws_vpc_security_group_ingress_rule" "redis_allow_airflow_apiserver" {
  security_group_id = aws_security_group.redis_sg.id
  description       = "allow airflow apiserver"
  from_port = 6379
  to_port   = 6379
  ip_protocol  = "tcp"
  referenced_security_group_id = aws_security_group.ecs_airflow_apiserver_sg.id
}

resource "aws_vpc_security_group_ingress_rule" "redis_allow_airflow_scheduler" {
  security_group_id = aws_security_group.redis_sg.id
  description       = "allow airflow scheduler"
  from_port = 6379
  to_port   = 6379
  ip_protocol  = "tcp"
  referenced_security_group_id = aws_security_group.ecs_airflow_scheduler_sg.id
}

resource "aws_vpc_security_group_ingress_rule" "redis_allow_airflow_worker" {
  security_group_id = aws_security_group.redis_sg.id
  description       = "allow airflow worker"
  from_port = 6379
  to_port   = 6379
  ip_protocol  = "tcp"
  referenced_security_group_id = aws_security_group.ecs_airflow_worker_sg.id
}

resource "aws_vpc_security_group_ingress_rule" "redis_allow_airflow_dag_processor" {
  security_group_id = aws_security_group.redis_sg.id
  description       = "allow airflow dag processor"
  from_port = 6379
  to_port   = 6379
  ip_protocol  = "tcp"
  referenced_security_group_id = aws_security_group.ecs_airflow_dag_processor_sg.id
}

resource "aws_vpc_security_group_ingress_rule" "redis_allow_airflow_triggerer" {
  security_group_id = aws_security_group.redis_sg.id
  description       = "allow airflow triggerer"
  from_port = 6379
  to_port   = 6379
  ip_protocol  = "tcp"
  referenced_security_group_id = aws_security_group.ecs_airflow_triggerer_sg.id
}
# --------------------
# egress
# --------------------
resource "aws_vpc_security_group_egress_rule" "redis_allow_all_traffic_ipv4" {
  security_group_id = aws_security_group.redis_sg.id
  description       = "to anywhere"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}