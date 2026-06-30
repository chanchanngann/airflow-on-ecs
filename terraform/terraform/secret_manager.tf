###################################
# Secret Mangager
###################################
# --------------------
# airflow_db (RDS) secret
# --------------------

resource "random_string" "airflow_db_password" {
  length      = 8
  special     = false
  lower       = true
  min_numeric = 0
}

resource "aws_secretsmanager_secret" "airflow_db" {
  name = "${var.name_prefix}-airflow-db"

  tags = merge(var.common_tags,
    {
      Name = "${var.name_prefix}-airflow-db"
    }
  )
}

resource "aws_secretsmanager_secret_version" "airflow_db" {
  secret_id = aws_secretsmanager_secret.airflow_db.id
  secret_string = jsonencode({
    "username" = var.postgres_username
    "password" = "${random_string.airflow_db_password.id}"
  })
}

# --------------------
# snowflake secret
# --------------------
resource "random_string" "snowflake_db" {
  length      = 8
  special     = false
  lower       = true
  min_numeric = 0
}

resource "aws_secretsmanager_secret" "snowflake_db" {
  name = "${var.name_prefix}-snowflake-db"

  tags = merge(var.common_tags,
    {
      Name = "${var.name_prefix}-snowflake-db"
    }
  )
}

resource "aws_secretsmanager_secret_version" "snowflake_db" {
  secret_id = aws_secretsmanager_secret.snowflake_db.id
  secret_string = jsonencode({
    "username" = var.snowflake_username
    "password" = "${random_string.snowflake_db.id}"
  })
}

# --------------------
# airflow fernet_key
# --------------------
resource "aws_secretsmanager_secret" "airflow_fernet_key" {
  name = "${var.name_prefix}-airflow-fernet-key"

  tags = merge(var.common_tags,
    {
      Name = "${var.name_prefix}-airflow-fernet-key"
    }
  )
}

resource "aws_secretsmanager_secret_version" "airflow_fernet_key" {
  secret_id = aws_secretsmanager_secret.airflow_fernet_key.id
  secret_string = jsonencode({
    "fernet_key" = "${var.airflow_fernet_key}"
  })
}

# --------------------
# airflow api_secret_key
# --------------------
resource "aws_secretsmanager_secret" "airflow_api_secret_key" {
  name = "${var.name_prefix}-airflow-api-secret-key"

  tags = merge(var.common_tags,
    {
      Name = "${var.name_prefix}-airflow-api-secret-key"
    }
  )
}

resource "aws_secretsmanager_secret_version" "airflow_api_secret_key" {
  secret_id = aws_secretsmanager_secret.airflow_api_secret_key.id
  secret_string = jsonencode({
    "secret_key" = "${var.airflow_api_secret_key}"
  })
}

# -----------------------------
# airflow_api_auth_jwt_secret
# -----------------------------
resource "aws_secretsmanager_secret" "airflow_api_auth_jwt_secret" {
  name = "${var.name_prefix}-airflow-api-auth-jwt-secret"

  tags = merge(var.common_tags,
    {
      Name = "${var.name_prefix}-airflow-api-auth-jwt-secret"
    }
  )
}

resource "aws_secretsmanager_secret_version" "airflow_api_auth_jwt_secret" {
  secret_id = aws_secretsmanager_secret.airflow_api_auth_jwt_secret.id
  secret_string = jsonencode({
    "jwt_secret" = "${var.airflow_api_auth_jwt_secret}"
  })
}

# ----------------------
# airflow admin password
# ----------------------
resource "aws_secretsmanager_secret" "airflow_admin" {
  name = "${var.name_prefix}-airflow-admin"

  tags = merge(var.common_tags,
    {
      Name = "${var.name_prefix}-airflow-admin"
    }
  )
}

resource "aws_secretsmanager_secret_version" "airflow_admin" {
  secret_id = aws_secretsmanager_secret.airflow_admin.id
  secret_string = jsonencode({
    "username" = "admin"
    "password" = var.airflow_admin_password
  })
}


# ----------------------
# gitea db password
# ----------------------

resource "random_string" "gitea_db_password" {
  length      = 8
  special     = false
  lower       = true
  min_numeric = 0
}

resource "aws_secretsmanager_secret" "gitea_db_password" {
  name = "${var.name_prefix}-gitea-database-password"

  tags = merge(var.common_tags,
    {
      Name = "${var.name_prefix}-gitea-database-password"
    }
  )
}

resource "aws_secretsmanager_secret_version" "gitea_db_password" {
  secret_id = aws_secretsmanager_secret.gitea_db_password.id
  secret_string = jsonencode({
    "password" = "${random_string.gitea_db_password.id}"
  })
}