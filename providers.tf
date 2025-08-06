terraform {
  required_version = "~>1.12"
  required_providers {
    aws = {
        source = "hashicorp/aws"
        version = "~>6.0"
    }
  }

  backend "s3" {
    bucket = "remote-state-terra"
    key = "remote-state-terra/dev/terraform.tfstate"
    region = "ap-south-1"
  }
}

provider "aws" {
    region = var.region
  
}

resource "aws_vpc" "public" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true

  tags = {
    name = "My-Public-VPC"
  }
}

resource "aws_subnet" "public-subnet" {
    vpc_id = aws_vpc.public.id
    cidr_block = "10.0.1.0/24"
    availability_zone = "us-east-1a"

    tags = {
      name = "My-Public-Subnet1"
    }
}

resource "aws_internet_gateway" "My-IGW" {
  vpc_id = aws_vpc.public.id

  tags = {
    name = "My-IGW-1"
  }
}

resource "aws_route_table" "Public-Route-table" {
  vpc_id = aws_vpc.public.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.My-IGW.id
  }

  tags = {
    name = "Public-Route-table-1"
  }
}

resource "aws_route_table_association" "one" {
  subnet_id = aws_subnet.public-subnet.id
  route_table_id = aws_route_table.Public-Route-table.id
}

module "security-group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "5.3.0"
  name        = "Web-App-SG"
  description = "Security group for user-service with custom ports open"
  vpc_id      = aws_vpc.public.id

  ingress_cidr_blocks      = ["0.0.0.0/0"]
  ingress_rules            = ["http-80-tcp"]
  egress_rules = ["all-all"]

  tags = {
    name = "My-Public-App-SG"
  }
}

data "aws_ami" "amzlinux2" {
  most_recent = true
  owners = [ "amazon" ]
  filter {
    name = "name"
    values = [ "amzn2-ami-hvm-*-gp2" ]
  }
  filter {
    name = "root-device-type"
    values = [ "ebs" ]
  }
  filter {
    name = "virtualization-type"
    values = [ "hvm" ]
  }
  filter {
    name = "architecture"
    values = [ "x86_64" ]
  }
}

resource "aws_instance" "Web-App" {
  ami = data.aws_ami.amzlinux2.id
  instance_type = "t2.micro"
  subnet_id = aws_subnet.public-subnet.id
  vpc_security_group_ids = [module.security-group.security_group_id]
  associate_public_ip_address = true
  user_data = file("${path.module}/app1-install.sh")


  tags = {
    name = "My-Web-APP"
  }

}

