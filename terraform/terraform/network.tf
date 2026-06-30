
###################################
# VPC, Subnet
###################################
module "vpc" {
  source               = "terraform-aws-modules/vpc/aws"
  name                 = var.vpc_name
  cidr                 = var.vpc_cidr
  azs                  = var.vpc_azs
  public_subnets       = var.vpc_public_subnets
  private_subnets      = var.vpc_private_subnets
  enable_dns_hostnames = true
  enable_dns_support   = true

  # enable NATGW
  enable_nat_gateway     = true
  single_nat_gateway     = true
  one_nat_gateway_per_az = false

  public_subnet_tags = {
    Name = "${var.vpc_name}-public"
  }

  private_subnet_tags = {
    Name = "${var.vpc_name}-private"
  }

  tags = merge(var.common_tags,
    {
      Name = var.vpc_name
    }
  )
}


###################################∂
# Gateway Endpoint for S3
###################################

resource "aws_vpc_endpoint" "s3_gateway_endpoint" {
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = module.vpc.private_route_table_ids

  tags = merge(var.common_tags,
    {
      Name = "s3-endpt"
    }
  )
}
