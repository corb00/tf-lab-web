variable "region" {
  default = "us-west-2"
}

variable "amis" {
  type = map(string)
  default = {
    "us-east-1" = "ami-0885b1f6bd170450c"
    "us-west-2" = "ami-07dd19a7900a1f049"
  }
}