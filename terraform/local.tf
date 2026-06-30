###################################
# ECS / airflow
###################################
locals {
  airflow_image = "${aws_ecr_repository.airflow.repository_url}:${var.airflow_image_tag}"

  airflow_secrets = [
    {
      name      = "AIRFLOW_ADMIN_PASSWORD"
      valueFrom = "${aws_secretsmanager_secret.airflow_admin.arn}:password::"
    },
    {
      name      = "AIRFLOW__CORE__FERNET_KEY"
      valueFrom = "${aws_secretsmanager_secret.airflow_fernet_key.arn}:fernet_key::"
    },
    {
      name      = "AIRFLOW__API__SECRET_KEY"
      valueFrom = "${aws_secretsmanager_secret.airflow_api_secret_key.arn}:secret_key::"
    },
    {
      name      = "AIRFLOW__API_AUTH__JWT_SECRET"
      valueFrom = "${aws_secretsmanager_secret.airflow_api_auth_jwt_secret.arn}:jwt_secret::"
    },    
  ]

  airflow_env = [
    {
      name      = "AIRFLOW__API_AUTH__JWT_ALGORITHM" # The algorithm name use when generating and validating JWT Task Identities.
      value     = "HS512" # “HS512” if jwt_secret is set, otherwise a key-type specific guess
    },
    {
      name  = "AIRFLOW__API__BASE_URL"
      value = var.airflow_base_url # public ALB URL
    },
    {
      name  = "AIRFLOW__CORE__EXECUTOR"
      value = "CeleryExecutor"
    },
    {
      # Airflow metadata DB
      # example: postgresql+psycopg2://user:password@rds-endpoint:5432/airflow
      name  = "AIRFLOW__DATABASE__SQL_ALCHEMY_CONN"
      value = "postgresql+psycopg2://${aws_db_instance.airflow_db.username}:${local.db_creds_airflow.password}@${aws_db_instance.airflow_db.address}:5432/${aws_db_instance.airflow_db.db_name}"
    },
    {
      name  = "AIRFLOW__CELERY__RESULT_BACKEND"
      value = "db+postgresql+psycopg2://${aws_db_instance.airflow_db.username}:${local.db_creds_airflow.password}@${aws_db_instance.airflow_db.address}:5432/${aws_db_instance.airflow_db.db_name}"
    },
    {
      # redis
      name  = "AIRFLOW__CELERY__BROKER_URL"
      value = "redis://${aws_elasticache_cluster.redis.cache_nodes[0].address}:6379/0"
    },
    {
      name  = "AIRFLOW__SCHEDULER__ENABLE_HEALTH_CHECK"
      value = "true"
    },
    {
      name  = "AIRFLOW__CORE__DAGS_ARE_PAUSED_AT_CREATION"
      value = "true"
    },
    {
      name  = "AIRFLOW__CORE__LOAD_EXAMPLES"
      value = "false"
    },
    { 
      # REMOTE loggig: Airflow task logs (what you see in Airflow UI)
      name  = "AIRFLOW__LOGGING__REMOTE_LOGGING"
      value = "true"
    },
    { # REMOTE loggig: will write to s3://<log-bucket>/airflow-task-logs/dag_id/task_id/run_id/...
      name  = "AIRFLOW__LOGGING__REMOTE_BASE_LOG_FOLDER"
      value = "s3://${var.log_s3_bucket}/airflow-task-logs"
    },
    { # REMOTE loggig: refers to an Airflow connection
      name  = "AIRFLOW__LOGGING__REMOTE_LOG_CONN_ID"
      value = "aws_default" 
      # aws_default - the default AWS connection Airflow uses. AWS provider will use ECS task IAM credentials automatically.
      # make sure this connection has permissions to access the s3 bucket
    },
    {
      name  = "AIRFLOW__CORE__AUTH_MANAGER"
      value = "airflow.providers.fab.auth_manager.fab_auth_manager.FabAuthManager"
    },
    {
      name  = "AIRFLOW_CONFIG"
      value = "/opt/airflow/config/airflow.cfg"
    },
    { # if Airflow worker ever falls back to served logs (using http://<worker-hostname>:8793/log/... instead of remote logging)
      name  = "AIRFLOW__CORE__HOSTNAME_CALLABLE" # It tells Airflow what hostname/IP to record for a worker task instance.
      value = "airflow.utils.net.get_host_ip_address" # using IP address as hostname 
    },
    {
      # This is for Airflow 3 workers talking to the API server
      name  = "AIRFLOW__CORE__EXECUTION_API_SERVER_URL"
      value = "${var.airflow_execution_api_server_url}" # use Cloud Map for internal worker -> apiserver communtion
    },

    { 
      # set to 1 for testing, otherwise Celery may be spawning multiple child processes which may lead to OOM.
      name  = "AIRFLOW__CELERY__WORKER_CONCURRENCY"
      value = "1"
    },
    {
      name  = "AIRFLOW__DAG_PROCESSOR__DAG_BUNDLE_CONFIG_LIST"
      value = jsonencode([
        {
          name      = "dags-folder"
          classpath = "airflow.providers.git.bundles.git.GitDagBundle"
          kwargs = {
            tracking_ref = "main"
            repo_url = "${var.gitea_repo_url_for_git_dag_bundle}" # use ECS service discovery
            git_conn_id  = "gitea_git"
            refresh_interval = 30
          }
        }
      ])
    }
  ]

  gitea_image = "${aws_ecr_repository.gitea.repository_url}:${var.gitea_image_tag}"

  gitea_env = [
    {
      name  = "GITEA__database__DB_TYPE"
      value = "postgres"
    },
    {
      name  = "GITEA__database__HOST"
      value = "${aws_db_instance.airflow_db.address}:5432"
    },
    {
      name  = "GITEA__database__NAME"
      value = "gitea"
    },
    {
      name  = "GITEA__database__USER"
      value = "gitea"
    },
    {
      name  = "GITEA__database__PASSWD"
      value = "gitea" # TODO: should move to `secrets` configuration and use secret manager instead?!
    },
    {
      name  = "GITEA__database__SSL_MODE"
      value = "require"
    },
    {
      name  = "GITEA__database__SCHEMA"
      value = "gitea"
    },
    {
      name  = "GITEA__server__ROOT_URL"
      value = "http://${var.gitea_host_name}"
    },
  ]
  
  # gitea_secrets = [
  #   {
  #     name      = "GITEA__database__PASSWD"
  #     valueFrom = "${aws_secretsmanager_secret.gitea_db_password.arn}:password::"
  #   }
  # ] 
}

###################################
# secrets
###################################

locals {
  db_creds_airflow = jsondecode(aws_secretsmanager_secret_version.airflow_db.secret_string)
  db_creds_snowflake  = jsondecode(aws_secretsmanager_secret_version.snowflake_db.secret_string)
  airflow_fernet_key  = jsondecode(aws_secretsmanager_secret_version.airflow_fernet_key.secret_string)
  airflow_admin  = jsondecode(aws_secretsmanager_secret_version.airflow_admin.secret_string)
  db_creds_gitea = jsondecode(aws_secretsmanager_secret_version.gitea_db_password.secret_string)
}
