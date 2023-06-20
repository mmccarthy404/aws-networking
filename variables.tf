variable "local" {
  type = object({
    env    = string
    region = string
  })
}

variable "vpc" {
  type = object({
    cidr = string
  })
}
