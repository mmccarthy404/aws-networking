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
  source        = "git::https://github.com/mmccarthy404/terraform-modules//terraform-aws-nat-instance?ref=1d9eb79583ecf325ee3df7f22796ba0b156b8abc" #v1.1.3
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

# Create Wireguard interface VPN enabling access to private subnets from peered interfaces
# Manually created in SSM Paramater Store as SecureString in JSON format like:
# [
#   {
#     "public_key": "<public-key-1>",
#     "allowed_ips": ["<allowed-ips-1>"]
#   },
#   {
#     "public_key": "<public-key-2>",
#     "allowed_ips": ["<allowed-ips-2>"]
#   }
# ]
data "aws_ssm_parameter" "wireguard_interface_peers" {
  name = "/prd/aws-networking/wireguard-interface-peers"
}

# Manually created in SSM Paramater Store as SecureString like:
# <private-key>
data "aws_ssm_parameter" "wireguard_interface_private_key" {
  name = "/prd/aws-networking/wireguard-interface-private-key"
}

resource "aws_eip" "wireguard" {
  domain = "vpc"

  tags = var.tags
}

module "wireguard" {
  source        = "git::https://github.com/mmccarthy404/terraform-modules//terraform-aws-wireguard?ref=31f57f443bd47e482e0073e430261ca2e8bbff7b" #v2.0.0
  instance_type = "t4g.nano"
  name          = "${local.name_prefix}-wireguard"
  subnet_id     = module.vpc.public_subnets[0]

  elastic_ip = aws_eip.wireguard.id

  wireguard_interface_peers       = jsondecode(data.aws_ssm_parameter.wireguard_interface_peers.value)
  wireguard_interface_private_key = data.aws_ssm_parameter.wireguard_interface_private_key.value

  tags = var.tags
}