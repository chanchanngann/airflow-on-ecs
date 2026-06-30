
###################################
# RDS
###################################
resource "aws_db_subnet_group" "airflow_db_subnet_group" {
  name = "${var.name_prefix}-db-subnet-grp"
  subnet_ids  = module.vpc.private_subnets

  tags = {
    Name = "${var.name_prefix}-db-subnet-grp"
  }
}

resource "aws_db_instance" "airflow_db" {
  identifier              = "${var.name_prefix}-postgres"  # only hyphen allowed
  storage_type            = "gp3"
  allocated_storage       = 20 # TODO: edit to -> 100
  max_allocated_storage   = 30 # TODO: edit to -> 500
  engine                  = "postgres"
  engine_version          = 17
  instance_class          = var.rds_instance_class # use db.r6g.large
  port                    = 5432
  db_name                 = "airflow"
  username                = local.db_creds_airflow.username
  password                = local.db_creds_airflow.password
  db_subnet_group_name    = aws_db_subnet_group.airflow_db_subnet_group.name
  vpc_security_group_ids  = [aws_security_group.rds_sg.id]
  publicly_accessible     = false
  apply_immediately       = true
  skip_final_snapshot     = true # TODO: set to false
  # final_snapshot_identifier = "airflow-final" # when skip_final_snapshot = false
  parameter_group_name    = aws_db_parameter_group.rds_pg_for_cdc.name
  # multi_az = true # TODO: required? create standby replica in another AZ
  storage_encrypted       = true # TODO: required?
  backup_retention_period = 10
  
  tags = merge(var.common_tags,
    {
      Name = "airflow-postgres-db"
    }
  )
}


###################################
# RDS - security group
###################################
resource "aws_security_group" "rds_sg" {
  name = "${var.name_prefix}-db-sg"
  description = "managed by Terraform"
  vpc_id      = module.vpc.vpc_id
  tags = merge(var.common_tags,
    {
      Name = "db-sg"
    }
  )
}

# --------------------
# ingress
# --------------------
resource "aws_vpc_security_group_ingress_rule" "rds_allow_bastion" {
  security_group_id = aws_security_group.rds_sg.id
  description       = "allow bastion"
  from_port = 5432
  to_port   = 5432
  ip_protocol  = "tcp"
  referenced_security_group_id = aws_security_group.bastion_sg.id
}

resource "aws_vpc_security_group_ingress_rule" "rds_allow_airflow_init_sg" {
  security_group_id = aws_security_group.rds_sg.id
  description       = "allow airflow init task"
  from_port = 5432
  to_port   = 5432
  ip_protocol  = "tcp"
  referenced_security_group_id = aws_security_group.ecs_airflow_init_sg.id
}

resource "aws_vpc_security_group_ingress_rule" "rds_allow_airflow_apiserver" {
  security_group_id = aws_security_group.rds_sg.id
  description       = "allow airflow apiserver"
  from_port = 5432
  to_port   = 5432
  ip_protocol  = "tcp"
  referenced_security_group_id = aws_security_group.ecs_airflow_apiserver_sg.id
}

resource "aws_vpc_security_group_ingress_rule" "rds_allow_airflow_scheduler" {
  security_group_id = aws_security_group.rds_sg.id
  description       = "allow airflow scheduler"
  from_port = 5432
  to_port   = 5432
  ip_protocol  = "tcp"
  referenced_security_group_id = aws_security_group.ecs_airflow_scheduler_sg.id
}

resource "aws_vpc_security_group_ingress_rule" "rds_allow_airflow_worker" {
  security_group_id = aws_security_group.rds_sg.id
  description       = "allow airflow worker"
  from_port = 5432
  to_port   = 5432
  ip_protocol  = "tcp"
  referenced_security_group_id = aws_security_group.ecs_airflow_worker_sg.id
}


resource "aws_vpc_security_group_ingress_rule" "rds_allow_airflow_dag_processor" {
  security_group_id = aws_security_group.rds_sg.id
  description       = "allow airflow dag processor"
  from_port = 5432
  to_port   = 5432
  ip_protocol  = "tcp"
  referenced_security_group_id = aws_security_group.ecs_airflow_dag_processor_sg.id
}

resource "aws_vpc_security_group_ingress_rule" "rds_allow_airflow_triggerer" {
  security_group_id = aws_security_group.rds_sg.id
  description       = "allow airflow triggerer"
  from_port = 5432
  to_port   = 5432
  ip_protocol  = "tcp"
  referenced_security_group_id = aws_security_group.ecs_airflow_triggerer_sg.id
}

resource "aws_vpc_security_group_ingress_rule" "rds_allow_gitea" {
  security_group_id = aws_security_group.rds_sg.id
  description       = "allow gitea"
  from_port = 5432
  to_port   = 5432
  ip_protocol  = "tcp"
  referenced_security_group_id = aws_security_group.ecs_gitea_sg.id
}
###################################
# RDS parameter group
###################################
resource "aws_db_parameter_group" "rds_pg_for_cdc" {

  name   = "rds-pg-for-airflow-db"
  family = "postgres17"

}

