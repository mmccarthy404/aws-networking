variable "name_prefix" {
  type = string
}

variable "region" {
  type = string
}

variable "environment" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "az_count" {
  type = number
}

variable "tags" {
  type = map(string)
}