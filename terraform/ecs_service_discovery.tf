###################################
# ECS service discovery
###################################
resource "aws_service_discovery_private_dns_namespace" "airflow" {
  name = "airflow.local"
  vpc  = module.vpc.vpc_id

  tags = merge(var.common_tags,
    {
      Name = "airflow.local"
    }
  )
}

###################################
# gitea
###################################

resource "aws_service_discovery_service" "gitea" {
  name = "gitea" # create gitea.airflow.local

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.airflow.id

    dns_records {
      type = "A"
      ttl  = 10 # The amount of time, in seconds, that you want DNS resolvers to cache the settings for this resource record set.
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1 # The number of consecutive health checks. Maximum value of 10.
  }

  tags = merge(var.common_tags,
    {
      Name = "gitea"
    }
  )
}


###################################
# airflow
###################################

resource "aws_service_discovery_service" "airflow_api" {
  name = "airflow-api" # create airflow-api.airflow.local

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.airflow.id

    dns_records {
      type = "A"
      ttl  = 10 # The amount of time, in seconds, that you want DNS resolvers to cache the settings for this resource record set.
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1 # The number of consecutive health checks. Maximum value of 10.
  }

  tags = merge(var.common_tags,
    {
      Name = "airflow-api"
    }
  )
}