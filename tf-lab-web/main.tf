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

#1  Create VPC
resource "aws_vpc" "prod" {
  cidr_block = "10.0.0.0/16"
    tags = {
    Site = "web1"
    Name = "prod-vpc"
  }
}

#2  Create Internet Gateway
resource "aws_internet_gateway" "gw1" {
  vpc_id = aws_vpc.prod.id
  tags = {
    Name = "web1-internet-gateway"
  }
}

#3  Create custom route table
resource "aws_route_table" "r1" {
  vpc_id = aws_vpc.prod.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw1.id
  }
  route {
    ipv6_cidr_block        = "::/0"
    gateway_id = aws_internet_gateway.gw1.id
  }
  tags = {
    Name = "web-main"
  }
}

#4  Create a subnet
resource "aws_subnet" "public1" {
  vpc_id     = aws_vpc.prod.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-west-2a"
  tags = {
    Name = "public1"
    AZ = "us-west-2a"
  }
}

#5  Associate subnet with route table
resource "aws_route_table_association" "a1" {
  subnet_id      = aws_subnet.public1.id
  route_table_id = aws_route_table.r1.id
}

#6  Create security group to allow traffic for ports 22,80,443
resource "aws_security_group" "web" {
  name        = "web"
  description = "Allow web inbound traffic"
  vpc_id      = aws_vpc.prod.id

  ingress {
    description = "TLS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "web from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "ssh from remote"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["108.29.90.182/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "web_ssh_remote"
  }
}

#7  Create a ENI with IP in subnet from step 4
resource "aws_network_interface" "eni0" {
  subnet_id       = aws_subnet.public1.id
  security_groups = [aws_security_group.web.id]

  #attachment {
  #  instance     = aws_instance.test.id
  #  device_index = 1
  #}
}

#8  Assign elastic IP to ENI in Step 7
resource "aws_eip" "public1_web1" {
  vpc = true
  network_interface         = aws_network_interface.eni0.id
  depends_on                = [aws_internet_gateway.gw1]
}

#9  Launch Ubuntu WEB instance and install/start apache2
resource "aws_instance" "web1" {
  ami           = var.amis[var.region]
  instance_type = "t2.micro"
  # subnet_id = aws_subnet.public1.id
  key_name="tf-lab"
  network_interface {
     device_index         = 0
     network_interface_id = aws_network_interface.eni0.id
  }
  user_data = <<-EOF
		#!/bin/bash
    sudo apt-get update
		sudo apt-get install -y apache2
		sudo systemctl start apache2
		sudo systemctl enable apache2
		echo "<h1>Deployed via Terraform</h1>" | sudo tee /var/www/html/index.html
	EOF
  tags = {
    Name = "web1_instance_in_prod_vpc"
    Env = "test"
    version = 0.1
  }
}

output "server_public_ip" {
   value = aws_eip.public1_web1.public_ip
}