provider "aws" {
  region = var.region
}

locals {
  name_prefix = "${var.name_prefix}-${var.region}-${var.environment}"
}

data "aws_availability_zones" "available" {
  state = "available"
}

module "vpc" {
  source = "git::https://github.com/terraform-aws-modules/terraform-aws-vpc.git?ref=c467edb180c38f493b0e9c6fdc22998a97dfde89" # commit hash of version 5.2.0

  name = local.name_prefix

  cidr            = var.vpc_cidr
  azs             = slice(data.aws_availability_zones.available.names, 0, var.az_count)
  private_subnets = [for i in range(var.az_count) : cidrsubnet(var.vpc_cidr, 8, i)]
  public_subnets  = [for i in range(var.az_count, var.az_count * 2) : cidrsubnet(var.vpc_cidr, 8, i)]

  map_public_ip_on_launch = true

  tags = var.tags
}