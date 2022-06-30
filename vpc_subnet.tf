resource "aws_vpc" "vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true

  tags = {
    Name = "vpc ${var.tag}"
  }
}

resource "aws_internet_gateway" "gateway" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "gateway ${var.tag}"
  }
}

resource "aws_route_table" "route-table" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gateway.id
  }

  tags = {
    Name = "test-env-route-table"
  }
}

resource "aws_route_table_association" "subnet-association" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.route-table.id
}

## Private Subnet

resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "10.0.0.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "private subnet vr testing ${var.tag}"
  }
}

resource "aws_route_table" "my_vpc_us_east_1a_private" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "Local Route Table for Isolated Private Subnet ${var.tag}"
  }
}

resource "aws_route_table_association" "my_vpc_us_east_1a_private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.my_vpc_us_east_1a_private.id
}

## Public Subnet

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "10.0.3.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "public subnet ${var.tag}"
  }
}

resource "aws_route_table" "my_vpc_us_east_1a_public" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gateway.id
  }

  tags = {
    Name = "Public Subnet Route Table ${var.tag}"
  }
}


#resource "aws_network_interface" "network_interface_to_open_ec2_to_rds" {
#  subnet_id   = aws_subnet.subnet.id
#  private_ips = ["172.16.10.100"]
#
#  tags = {
#    Name = var.tag  # todo other tags
#  }
#}
