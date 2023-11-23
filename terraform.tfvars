name_prefix = "vpc"
region      = "us-east-1"
environment = "prd"
vpc_cidr    = "10.0.0.0/16"
az_count    = 3

tags = {
  terraform   = "true"
  project     = "aws-core-infra"
  environment = "prd"
}