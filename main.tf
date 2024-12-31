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
  source = "git::https://github.com/terraform-aws-modules/terraform-aws-vpc?ref=c467edb180c38f493b0e9c6fdc22998a97dfde89" #v5.2.0

  name = local.name_prefix

  cidr            = var.vpc_cidr
  azs             = slice(data.aws_availability_zones.available.names, 0, var.az_count)
  private_subnets = [for i in range(var.az_count) : cidrsubnet(var.vpc_cidr, 8, i)]
  public_subnets  = [for i in range(var.az_count, var.az_count * 2) : cidrsubnet(var.vpc_cidr, 8, i)]

  map_public_ip_on_launch = true

  tags = var.tags
}

module "nat" {
  source        = "git::https://github.com/mmccarthy404/terraform-modules//terraform-aws-nat-instance?ref=ea6885468781e0e15c54034b27efeb2c3a1a1a2d" #v1.1.2
  instance_type = "t4g.nano"
  name          = "${local.name_prefix}-nat"
  subnet_id     = module.vpc.public_subnets[0]

  tags = var.tags
}

resource "aws_route" "nat" {
  for_each = toset(module.vpc.private_route_table_ids)

  route_table_id         = each.value
  destination_cidr_block = "0.0.0.0/0"
  network_interface_id   = module.nat.network_interface.id
}
