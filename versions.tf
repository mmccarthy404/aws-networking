terraform {
  #checkov:skip=CKV_TF_3:Backend config upgraded w/ state lock during apply
  backend "s3" {}
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.50"
    }
  }
}
