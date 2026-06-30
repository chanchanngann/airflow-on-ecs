###################################
# EFS
###################################

resource "aws_efs_file_system" "gitea" {

  creation_token = "gitea" # A unique name (a maximum of 64 characters are allowed) 
  # used as reference when creating the Elastic File System to ensure idempotent file system creation. 

  # Enable encryption at rest
  encrypted  = true
  kms_key_id = aws_kms_key.efs.arn

  # Performance mode: generalPurpose or maxIO
  performance_mode = "generalPurpose"

  # Throughput mode: bursting or provisioned
  throughput_mode = "bursting"

  # lifecycle_policy {
  #   transition_to_ia = "AFTER_30_DAYS"
  # }

  depends_on = [
    aws_iam_role_policy_attachment.ecs_access_efs
  ]

  tags = merge(var.common_tags,
    {
      Name = "${var.name_prefix}-gitea"
    }
  )
}

###################################
# KMS key for EFS encryption
###################################
 
resource "aws_kms_key" "efs" {
  description             = "KMS key for EFS encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true
}

###################################
# EFS mount targets 
###################################
# create mount target in ALL private subnets that ECS tasks may run.
# otherwise if ecs task = DIFF AZ as EFS mount target
# => traffic must cross AZ boundaries (extra latency, cross-AZ data charges...)

resource "aws_efs_mount_target" "private_a" {
  file_system_id  = aws_efs_file_system.gitea.id
  subnet_id       = module.vpc.private_subnets[0]

  security_groups = [
    aws_security_group.efs_sg.id
  ]
}

resource "aws_efs_mount_target" "private_b" {
  file_system_id  = aws_efs_file_system.gitea.id
  subnet_id       = module.vpc.private_subnets[1]

  security_groups = [
    aws_security_group.efs_sg.id
  ]
}

resource "aws_efs_mount_target" "private_c" {
  file_system_id  = aws_efs_file_system.gitea.id
  subnet_id       = module.vpc.private_subnets[2]

  security_groups = [
    aws_security_group.efs_sg.id
  ]
}

###################################
# EFS access point 
###################################

resource "aws_efs_access_point" "gitea" {
  file_system_id = aws_efs_file_system.gitea.id

  # Set the POSIX user for file operations
  # Tell EFS to ignore the UID/GID coming from the client (ECS task)
  # Treat every request through this access point as UID 1000/GID 1000
  # that means even if application run as root uid=0, files writen as uid=1000
  # scenario: Multiple applications share one EFS and you want hard isolation.
  posix_user {
    uid = 1000
    gid = 1000
  }

  root_directory {
    path = "/gitea" # create this path if not already exists 

    creation_info {
      owner_gid   = 1000
      owner_uid   = 1000
      permissions = "755"
    }
  }

  tags = merge(var.common_tags,
    {
      Name = "${var.name_prefix}-gitea"
    }
  )
}


###################################
# EFS IAM role
###################################


# No EFS-specific IAM policy required.
# you can enable IAM in `authorization_config` to EFS access_point in aws_ecs_task_definition
# then the ECS task role would need `elasticfilesystem` permission to access EFS


###################################
# EFS File System Policy
###################################

# restrict access to authorized principals only
resource "aws_efs_file_system_policy" "gitea" {
  file_system_id = aws_efs_file_system.gitea.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EnforceEncryptionInTransit"
        Effect = "Deny"
        Principal = {
          AWS = "*"
        }
        Action    = "*"
        Resource  = aws_efs_file_system.gitea.arn
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      },
      {
        Sid    = "AllowECSTaskAccess"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.ecs_task_role_gitea.arn
        }
        Action = [
          "elasticfilesystem:ClientMount",
          "elasticfilesystem:ClientWrite"
        ]
        Resource = aws_efs_file_system.gitea.arn
      }
    ]
  })
}



###################################
# EFS security group 
###################################
resource "aws_security_group" "efs_sg" {
  name = "${var.name_prefix}-efs-sg"
  description = "managed by Terraform"
  vpc_id      = module.vpc.vpc_id
  tags = merge(var.common_tags,
    {
      Name = "${var.name_prefix}-efs-sg"
    }
  )
}

# --------------------
# ingress
# --------------------
resource "aws_vpc_security_group_ingress_rule" "efs_allow_gitea" {
  security_group_id = aws_security_group.efs_sg.id
  description       = "allow gitea ecs service"
  from_port = 2049 # EFS use port 2049
  to_port   = 2049
  ip_protocol  = "tcp"
  referenced_security_group_id = aws_security_group.ecs_gitea_sg.id
}

# --------------------
# egress
# --------------------
resource "aws_vpc_security_group_egress_rule" "efs_allow_all_traffic_ipv4" {
  security_group_id = aws_security_group.efs_sg.id
  description       = "to anywhere"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}