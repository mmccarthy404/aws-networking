locals {
  az_count = 2
}

# resource "aws_eip" "nat" {
#   count  = local.az_count
#   domain = "vpc"

#   lifecycle {
#     prevent_destroy = true
#   }
# }

data "aws_availability_zones" "available" {
  state = "available"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.0.0"

  name = join("-", [
    "vpc",
    var.local.region,
    var.local.env
  ])

  cidr            = var.vpc.cidr
  azs             = slice(data.aws_availability_zones.available.names, 0, local.az_count)
  private_subnets = [for i in range(local.az_count) : cidrsubnet(var.vpc.cidr, 8, i)]
  public_subnets  = [for i in range(local.az_count, local.az_count * 2) : cidrsubnet(var.vpc.cidr, 8, i)]

  enable_nat_gateway = false
  single_nat_gateway = false
  reuse_nat_ips      = true # Skip creation of EIPs for the NAT Gateways
  # external_nat_ip_ids = aws_eip.nat.*.id # IPs specified here as input to the module
}