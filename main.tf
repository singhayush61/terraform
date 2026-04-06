# Configure the AWS Provider
provider "aws" {
  region = "ap-south-1"
}

# Retrieve the list of AZs
data "aws_availability_zones" "available" {}

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

resource "aws_s3_bucket" "my-new-bucket-s3-ayushaws" {
  bucket = "my-new-bucket-s3-ayushaws-tf"

  tags = {
    Name = "My S3 Bucket"
    Purpose = "Intro to Resource Blocks Lab"
  }
}

resource "aws_s3_bucket_acl" "my_new-bucket-s3-ayushaws-acl" {
  bucket = aws_s3_bucket.my-new-bucket-s3-ayushaws.id
  acl    = "private"
}