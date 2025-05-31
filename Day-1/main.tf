# Retrieving the list of availability zones in the current AWS region
data "aws_availability_zones" "available" {}
data "aws_region" "current" {}

# Define the VPC
resource "aws_vpc" "demo_vpc" {
    cidr_block = var.vpc_cidr
    tags = {
        Name = var.vpc_name
        environment = "development"
        Terraform = "true"
    }
}

#Deploy the private subnets
resource "aws_subnet" "private_subnets" {
    for_each = var.private_subnets
    vpc_id = aws_vpc.demo_vpc.id
    cidr_block = cidrsubnet(var.vpc_cidr, 8, each.value)
    availability_zone = tolist(data.aws_availability_zones.available.names)[each.value]
    tags = {
        Name = each.key
        Terraform = "true"
    }
}

# Deploy the public subnets
resource "aws_subnet" "public_subnets" {
    for_each = var.public_subnets
    vpc_id = aws_vpc.demo_vpc.id
    cidr_block = cidrsubnet(var.vpc_cidr, 8, each.value + 100)
    availability_zone = tolist(data.aws_availability_zones.available.names)[each.value]
    map_public_ip_on_launch = true
    tags = {
        Name = each.key
        Terraform = "true"
    }
}

# Create an Internet Gateway for the VPC
resource "aws_internet_gateway" "igw" {
    vpc_id = aws_vpc.demo_vpc.id
    tags = {
        Name = "demo-igw"
    }
}

#Create EIP for the NAT Gateway
resource "aws_eip" "nat_gateway_eip" {
  domain = "vpc"
  depends_on = [aws_internet_gateway.igw]
  tags = {
    Name = "demo-nat-eip"
  }
}

# Create a NAT Gateway 
resource "aws_nat_gateway" "nat" {
  depends_on = [aws_subnet.public_subnets]
  allocation_id = aws_eip.nat_gateway_eip.id
  subnet_id = aws_subnet.public_subnets["public_subnet_1"].id
  tags = {
    Name = "demo-nat-gateway"
  }
}


#Create an route table for the public and private subnets
resource "aws_route_table" "public_rt" {
    vpc_id = aws_vpc.demo_vpc.id

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.igw.id
    }
    tags = {
        Name = "demo-public-rt"
        Terraform = "true"
    }
}

resource "aws_route_table" "private_rt" {
    vpc_id = aws_vpc.demo_vpc.id
    route {
        cidr_block = "0.0.0.0/0"
        nat_gateway_id = aws_nat_gateway.nat.id
    }
    tags = {
        Name = "demo-private-rt"
        Terraform = "true"
    }
}

resource "aws_route_table_association" "public" {
  depends_on = [aws_subnet.public_subnets]
  route_table_id = aws_route_table.public_rt.id
  for_each = aws_subnet.public_subnets
  subnet_id = each.value.id
}

resource "aws_route_table_association" "private" {
  depends_on = [aws_subnet.private_subnets]
  route_table_id = aws_route_table.private_rt.id
  for_each = aws_subnet.private_subnets
  subnet_id = each.value.id
}