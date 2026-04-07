# Configure the AWS Provider
provider "aws" {
  region = var.aws_region
}

# Data Sources
data "aws_availability_zones" "available" {}
data "aws_region" "current" {}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

# Locals for Tagging
locals {
  team        = "api_mgmt_dev"
  application = "corp_api"
}

# 1. Network Infrastructure (Free Tier)
resource "aws_vpc" "vpc" {
  cidr_block = var.vpc_cidr
  tags = {
    Name      = var.vpc_name
    Terraform = "true"
  }
}

resource "aws_subnet" "private_subnets" {
  for_each          = var.private_subnets
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, each.value)
  availability_zone = data.aws_availability_zones.available.names[each.value % length(data.aws_availability_zones.available.names)]
  tags = { Name = each.key }
}

resource "aws_subnet" "public_subnets" {
  for_each                = var.public_subnets
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, each.value + 100)
  availability_zone       = data.aws_availability_zones.available.names[each.value % length(data.aws_availability_zones.available.names)]
  map_public_ip_on_launch = true
  tags = { Name = each.key }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "public_assoc" {
  for_each       = aws_subnet.public_subnets
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public_rt.id
}

# 2. S3 Storage (Free Tier)
resource "aws_s3_bucket" "my_bucket" {
  bucket = "my-new-bucket-s3-ayushaws-tf"
}

resource "aws_s3_bucket_ownership_controls" "s3_oc" {
  bucket = aws_s3_bucket.my_bucket.id
  rule { object_ownership = "BucketOwnerPreferred" }
}

resource "aws_s3_bucket_acl" "s3_acl" {
  depends_on = [aws_s3_bucket_ownership_controls.s3_oc]
  bucket     = aws_s3_bucket.my_bucket.id
  acl        = "private"
}

# 3. Security Groups (Free)
resource "aws_security_group" "web_sg" {
  name   = "web-server-sg"
  vpc_id = aws_vpc.vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 4. SSH Key Pair Generation (Free)
resource "tls_private_key" "key" {
  algorithm = "RSA"
}

resource "local_file" "private_key" {
  content  = tls_private_key.key.private_key_pem
  filename = "MyAWSKey.pem"
}

resource "aws_key_pair" "deployer" {
  key_name   = "MyAWSKey"
  public_key = tls_private_key.key.public_key_openssh
}

# 5. EC2 Instance (Zero-Cost Configuration)
resource "aws_instance" "ubuntu_server" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  
  # Deploy to PRIVATE subnet for $0 cost
  subnet_id = aws_subnet.private_subnets["private_subnet_1"].id
  
  # Disabling Public IP to avoid the $0.005/hr fee
  associate_public_ip_address = false 

  vpc_security_group_ids = [aws_security_group.web_sg.id]
  key_name               = aws_key_pair.deployer.key_name

  # Automation: This installs Nginx without needing a "hanging" SSH connection
  user_data = <<-EOF
              #!/bin/bash
              sudo apt-get update -y
              sudo apt-get install -y nginx
              echo "<h1>Hello Ayush - Free Tier Active</h1>" | sudo tee /var/www/html/index.html
              sudo systemctl start nginx
              EOF

  tags = {
    Name  = "Ubuntu-Free-Server"
    Owner = local.team
  }
}