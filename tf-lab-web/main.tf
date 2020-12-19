terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 2.70"
    }
  }
}

provider "aws" {
  profile = "default"
  region  = var.region
}

resource "aws_vpc" "prod" {
  cidr_block = "10.0.0.0/16"
  
  tags = {
    Site = "test-web-site"
    Name = "prod-vpc"
  }
}

resource "aws_subnet" "main" {
  vpc_id     = aws_vpc.prod.id
  cidr_block = "10.0.1.0/24"

  tags = {
    Name = "Main"
  }
}



resource "aws_instance" "example" {
  ami           = var.amis[var.region]
  instance_type = "t2.micro"
  subnet_id = aws_subnet.main.id 
  tags = {
    Name = "first_instance_in prod_vpc"
    Env = "test"
    version = 0.1
  }
}
