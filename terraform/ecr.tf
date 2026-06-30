###################################
# ECR (private repo)
###################################

# --------------------
# Airflow
# --------------------

resource "aws_ecr_repository" "airflow" {
  name                 = var.ecr_repo_name
  image_tag_mutability = "MUTABLE" # allows overwriting tags

  image_scanning_configuration {
    scan_on_push = true # scans image for vulnerabilities after push
  }

  tags = merge(var.common_tags,
    {
      Name = var.ecr_repo_name
    }
  )
}

resource "aws_ecr_lifecycle_policy" "airflow_lifecycle" {
  repository = aws_ecr_repository.airflow.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 20 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 20
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# --------------------
# Gitea
# --------------------
resource "aws_ecr_repository" "gitea" {
  name                 = var.ecr_repo_name_gitea
  image_tag_mutability = "MUTABLE" # allows overwriting tags

  image_scanning_configuration {
    scan_on_push = true # scans image for vulnerabilities after push
  }

  tags = merge(var.common_tags,
    {
      Name = var.ecr_repo_name_gitea
    }
  )
}

resource "aws_ecr_lifecycle_policy" "gitea_lifecycle" {
  repository = aws_ecr_repository.gitea.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 20 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 20
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
