variable "local" {
  type = object({
    env    = string
    region = string
  })
}

variable "vpc" {
  type = object({
    name_suffix = string
    cidr        = string
  })
}
