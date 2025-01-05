provider "aws" {
  region = var.region
}

locals {
  name_prefix = "${var.name_prefix}-${var.region}-${var.environment}"
}

data "aws_availability_zones" "available" {
  state = "available"
}

# Create VPC and related infrastructure
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

# Create NAT instance and create appropriate routes in private route tables
module "nat" {
  source        = "git::https://github.com/mmccarthy404/terraform-modules//terraform-aws-nat-instance?ref=672ef55363e0bc5194776eba3f92366542570d6f" #v1.1.3
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

# Create WireGuard interface VPN enabling access to private subnets from peered interfaces
# Manually created in SSM Parameter Store as SecureString
data "aws_ssm_parameter" "wireguard_interface_private_key" {
  name = "/prd/aws-networking/wireguard-interface-private-key"
}

# Manually created in SSM Parameter Store as SecureString
data "aws_ssm_parameter" "wireguard_peer_public_key" {
  name = "/prd/aws-networking/wireguard-peer-public-key"
}

# Manually created in SSM Parameter Store as SecureString
data "aws_ssm_parameter" "wireguard_peer_source_ip" {
  name = "/prd/aws-networking/wireguard-peer-source-ip"
}

resource "aws_eip" "wireguard" {
  #checkov:skip=CKV2_AWS_19:EIP provisioned outside WireGuard module to separate life cycles, attachment to ENI made within module
  domain = "vpc"

  tags = var.tags
}

module "wireguard" {
  source        = "git::https://github.com/mmccarthy404/terraform-modules//terraform-aws-wireguard?ref=46068c23a79be08e86c15b4452ab3a5c7d74a7ae" #v2.1.0
  instance_type = "t4g.nano"
  name          = "${local.name_prefix}-wireguard"
  subnet_id     = module.vpc.public_subnets[0]

  elastic_ip = aws_eip.wireguard.id

  wireguard_interface_private_key = data.aws_ssm_parameter.wireguard_interface_private_key.value
  wireguard_peer_public_key       = data.aws_ssm_parameter.wireguard_peer_public_key.value
  wireguard_peer_source_ip        = data.aws_ssm_parameter.wireguard_peer_source_ip.value

  tags = var.tags
}