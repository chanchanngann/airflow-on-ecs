# AWS account_id, arn
data "aws_caller_identity" "current" {}


data "aws_availability_zones" "available" {
  state = "available"
}


###################################
# Bastion
###################################
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

data "aws_iam_policy_document" "sts" {
  statement {
    sid    = "1"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
    actions = [
      "sts:AssumeRole"
    ]
  }
}

###################################
# ECS
###################################

data "aws_iam_policy_document" "ecs_assume_role" {
  statement {
    sid    = "1"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
    actions = [
      "sts:AssumeRole"
    ]
  }
}

###################################
# S3 gateway
###################################
data "aws_iam_policy_document" "s3_gateway" {
  statement {
    sid    = "1"
    effect = "Allow"
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    actions = [
      "s3:GetObject"
    ]
    resources = ["arn:aws:s3:::amazonlinux.${var.region}.amazonaws.com/*",
    "arn:aws:s3:::amazonlinux-2-repos-${var.region}/*"]
  }
}




