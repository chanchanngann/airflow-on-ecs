###################################
# Bastion host
###################################
resource "aws_instance" "bastion" {
  
  count = var.enable_bastion ? 1 : 0 # enable/disable the resource

  ami                         = data.aws_ami.amazon_linux_2023.id
  instance_type               = var.bastion_instance_type
  iam_instance_profile        = aws_iam_instance_profile.bastion_instance_profile.name
  subnet_id                   = module.vpc.public_subnets[0]
  vpc_security_group_ids      = [aws_security_group.bastion_sg.id]
  associate_public_ip_address = true
  key_name                    = var.ec2_key_name
  # user_data                   = file("../scripts/user_data.sh")

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  tags = merge(var.common_tags,
    {
      Name = "bastion-host"
    }
  )
}

resource "aws_eip" "bastion" {

  count = var.enable_bastion ? 1 : 0 # enable/disable the resource

  instance = try(aws_instance.bastion[0].id, null)
  domain   = "vpc"
}


###################################
# Bastion instance profile (IAM)
###################################
resource "aws_iam_role" "instance" {
  name_prefix        = "instance-profile-bastion-"
  assume_role_policy = data.aws_iam_policy_document.sts.json
}

resource "aws_iam_instance_profile" "bastion_instance_profile" {
  name_prefix = "instance-profile-bastion-"
  role        = aws_iam_role.instance.name
}

resource "aws_iam_role_policy" "access_ecr" {
  name = "access-ecr"
  role = aws_iam_role.instance.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid    = "ECRLogin"
        Effect = "Allow"

        Action = [
          "ecr:GetAuthorizationToken"
        ]

        Resource = "*"
      },
      {
        Sid    = "ECRPush"
        Effect = "Allow"

        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:CompleteLayerUpload",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
          "ecr:UploadLayerPart"
        ]

        Resource = [
          aws_ecr_repository.airflow.arn,
          aws_ecr_repository.gitea.arn
        ]
      }
    ]
  })
}

###################################
# Bastion host security group
###################################

resource "aws_security_group" "bastion_sg" {
  name = "${var.name_prefix}-bastion-sg"
  vpc_id      = module.vpc.vpc_id

  tags = merge(var.common_tags,
    {
      Name = "${var.name_prefix}-bastion-sg"
    }
  )
}

# --------------------
# ingress
# --------------------

resource "aws_vpc_security_group_ingress_rule" "bastion_allow_ssh" {
  security_group_id = aws_security_group.bastion_sg.id
  description       = "allow ssh from local"
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

# --------------------
# egress
# --------------------

resource "aws_vpc_security_group_egress_rule" "bastion_allow_https" {
  security_group_id = aws_security_group.bastion_sg.id
  description       = "outbound to https"
  from_port   = 443
  to_port     = 443
  ip_protocol = "tcp"
  cidr_ipv4   = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "bastion_allow_http" {
  security_group_id = aws_security_group.bastion_sg.id
  description       = "outbound to http"
  from_port   = 80
  to_port     = 80
  ip_protocol = "tcp"
  cidr_ipv4   = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "bastion_allow_s3_gateway" {
  security_group_id = aws_security_group.bastion_sg.id
  description       = "outbound to s3 via Gateway Endpoint"
  ip_protocol = "-1"
  prefix_list_id = aws_vpc_endpoint.s3_gateway_endpoint.prefix_list_id
}

resource "aws_vpc_security_group_egress_rule" "bastion_allow_rds" {
  security_group_id = aws_security_group.bastion_sg.id
  description       = "outbound to rds"
  from_port   = 5432
  to_port     = 5432
  ip_protocol = "tcp"
  referenced_security_group_id = aws_security_group.rds_sg.id

}

