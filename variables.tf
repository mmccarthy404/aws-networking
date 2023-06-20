variable "local" {
  type = object({
    env    = string
    region = string
  })
}

varvariable "vpc" {
  type = object({
    cidr = string
  })
}
