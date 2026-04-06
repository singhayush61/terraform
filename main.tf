# Configure the AWS Provider
provider "aws" {
  region = "ap-south-1"
}

# Retrieve the list of AZs
data "aws_availability_zones" "available" {}
data "aws_region" "current" {}

locals {
  team = "api_mgmt_dev"
  application = "corp_api"
  server_name = "ec2-${var.environment}-api-${var.variables_sub_az}"
}


# 1. Define the VPC (Free)
resource "aws_vpc" "vpc" {
  cidr_block = var.vpc_cidr
  tags = {
    Name        = var.vpc_name
    Environment = "environment"
    Terraform   = "true"
  }
}

# 2. Deploy Private Subnets (Free)
resource "aws_subnet" "private_subnets" {
  for_each          = var.private_subnets
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, each.value)
  availability_zone = data.aws_availability_zones.available.names[each.value % length(data.aws_availability_zones.available.names)]
  tags = {
    Name      = each.key
    Terraform = "true"
  }
}

# 3. Deploy Public Subnets (Free)
resource "aws_subnet" "public_subnets" {
  for_each                = var.public_subnets
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, each.value + 100)
  availability_zone       = data.aws_availability_zones.available.names[each.value % length(data.aws_availability_zones.available.names)]
  map_public_ip_on_launch = true
  tags = {
    Name      = each.key
    Terraform = "true"
  }
}

# 4. Internet Gateway (Free)
resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "igw"
  }
}

# 5. Public Route Table (Free)
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet_gateway.id
  }
  tags = {
    Name      = "public_rtb"
    Terraform = "true"
  }
}

# 6. Private Route Table (Free - No NAT Gateway route)
resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.vpc.id
  # No route to 0.0.0.0/0 here means no NAT Gateway needed!
  tags = {
    Name      = "private_rtb"
    Terraform = "true"
  }
}

# 7. Route Table Associations (Free)
resource "aws_route_table_association" "public" {
  for_each       = aws_subnet.public_subnets
  route_table_id = aws_route_table.public_route_table.id
  subnet_id      = each.value.id
}

resource "aws_route_table_association" "private" {
  for_each       = aws_subnet.private_subnets
  route_table_id = aws_route_table.private_route_table.id
  subnet_id      = each.value.id
}

# 1. Your existing Bucket
resource "aws_s3_bucket" "my-new-bucket-s3-ayushaws" {
  bucket = "my-new-bucket-s3-ayushaws-tf"
  tags = {
    Name = "My S3 Bucket"
  }
}

# 2. ADD THIS: This resource "enables" ACLs for the bucket
resource "aws_s3_bucket_ownership_controls" "example" {
  bucket = aws_s3_bucket.my-new-bucket-s3-ayushaws.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

# 3. Your existing ACL (Ensure it depends on the controls above)
resource "aws_s3_bucket_acl" "my_new-bucket-s3-ayushaws-acl" {
  depends_on = [aws_s3_bucket_ownership_controls.example]

  bucket = aws_s3_bucket.my-new-bucket-s3-ayushaws.id
  acl    = "private"
}

resource "aws_security_group" "my-new-security-group" {
  name        = "web_server_inbound"
  description = "Allow inbound traffic on tcp/443"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    description = "Allow 443 from the Internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "web_server_inbound"
    Purpose = "Intro to Resource Blocks Lab"
  }
}

# Find the latest Ubuntu 22.04 AMI in the Mumbai region
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # This is the official Canonical (Ubuntu) Account ID

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "web_server" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  subnet_id     = aws_subnet.public_subnets["public_subnet_1"].id
  tags = {
    Name = local.server_name
    Owner = local.team
    App = local.application
  }
}

resource "aws_subnet" "variables-subnet" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = var.variables_sub_cidr
  availability_zone       = var.variables_sub_az
  map_public_ip_on_launch = var.variables_sub_auto_ip

  tags = {
    Name      = "sub-variables-${var.variables_sub_az}"
    Terraform = "true"
  }
}