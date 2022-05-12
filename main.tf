terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.27"
    }
  }

  required_version = ">= 0.14.9"
}

###########
# VARIABLES
###########

variable "vrtesting_environment" {
  description = "Environment"
  type        = string
}

provider "aws" {
  profile = "default"
  region  = "us-east-1"
}

variable "keypair" {
  description = "The keypair for connecting to the EC2 instance"
  type        = string
}

variable "vrtesting_rds_username" {
  description = "The username for the DB master user"
  type        = string
}

variable "vrtesting_rds_password" {
  description = "The password for the DB master user"
  type        = string
}

variable "vrtesting_rds_snapshot" {
  description = "The name of the RDS snapshot"
  type        = string
}

variable "vrtesting_s3_screenshot_bucket_name" {
  description = "The bucket for storing comparison images"
  type        = string
}

variable "vrtesting_rds_subnet_group" {
  description = "The subnet group of the RDS instance"
  type        = string
}

variable "vrtesting_rds_publicly_accessible" {
  description = "Is the RDS instance publicly accessible"
  type        = string
}

variable "website_auth_github_id" {
  description = "GITHUB_ID for developer app"
  type        = string
}

variable "website_auth_github_secret" {
  description = "GITHUB_SECRET for developer app"
  type        = string
}

variable "website_nextauth_secret" {
  description = "NextAuth secret"
  type        = string
}

variable "website_github_deploy_key" {
  description = "To access other GitHub repositories via npm install (to be deprecated by packages someday)"
  type        = string
}

variable "website_github_personal_or_oauth_token" {
  description = "GitHub personal or OAuth token to clone the GitHub repository"
  type        = string
}

variable "tag" {
  description = "The tag for all resources related to this project"
  type        = string
}


data "template_file" "init" {
  template = file("${path.module}/scripts/setup_web_server.tpl")

  vars = {
    GITHUB_ID     = "${var.website_auth_github_id}"
    GITHUB_SECRET = "${var.website_auth_github_secret}"
    NEXTAUTH_SECRET    = "${var.website_nextauth_secret}"
  }
}

##########
# DATABASE
##########

resource "aws_db_instance" "visual_regression_rds_instance" {
  engine         = "mysql"
  engine_version = "8.0.23"
  instance_class = "db.t2.micro"
  // required unless a snapshot identifier is provided
  // if using a snapshot the database already has a master username
  # username                  = var.vrtesting_rds_username
  password = var.vrtesting_rds_password
  # snapshot_identifier = data.aws_db_snapshot.latest_snapshot.id
  snapshot_identifier       = var.vrtesting_rds_snapshot
  final_snapshot_identifier = "${var.vrtesting_environment}-app-db-snaphot-${replace(timestamp(), ":", "-")}"
  db_subnet_group_name      = aws_db_subnet_group.db_subnet.name
  publicly_accessible       = var.vrtesting_rds_publicly_accessible

  #  lifecycle {
  #    ignore_changes = [
  #      final_snapshot_identifier,
  #    ]
  #  }

  lifecycle {
    ignore_changes = [snapshot_identifier]
  }
}

resource "aws_db_subnet_group" "db_subnet" {
  name       = "db_subnet_private"
  subnet_ids = [aws_subnet.private.id, aws_subnet.public.id]

  tags = {
    Name = "subnet ${var.tag}"
  }
}

# todo this is not working
#data "aws_db_snapshot" "latest_snapshot" {
#  db_instance_identifier = aws_db_instance.visual_regression_rds_instance.id
#  most_recent            = true
#}

#
#data "aws_db_snapshot" "latest_prod_snapshot" {
#  db_instance_identifier = aws_db_instance.visual_regression_rds_instance.id
#  db_snapshot_identifier = var.vrtesting_rds_snapshot
#}

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

## Security Groups

resource "aws_security_group" "security_group" {
  name   = "Security Group ${var.tag}"
  vpc_id = aws_vpc.vpc.id

  # SSH (todo do not use in production)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP access via the web
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # allow EC2 to connect to RDS, not sure if this is correct
  ingress {
    from_port   = 80
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.vpc.cidr_block] # todo not sure if this is right
  }

  # allow everything that is required since terraform removes it automatically (https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Security Group ${var.tag}"
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

#########
# WEBSITE
#########

data "aws_ami" "amazon_linux" {
  most_recent = true

  filter {
    name   = "image-id"
    values = ["ami-0022f774911c1d690"]
  }

  # owner of the AMI
  owners = ["137112412989"]
}

resource "aws_instance" "web" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = "t2.small"
  vpc_security_group_ids      = [aws_security_group.security_group.id]
  subnet_id                   = aws_subnet.public.id
  associate_public_ip_address = true

  user_data = data.template_file.init.rendered

  key_name = "${var.tag}-deploy-key"

  tags = {
    Name = "Linux ${var.tag}"
  }
}

resource "aws_key_pair" "deployer" {
  key_name   = "${var.tag}-deploy-key"
  public_key = var.keypair
}

## todo Launch RDS into VCS - RDS is above ^^^
## todo should RDS use or go off migration (not important for initial deployment test)

###########
# S3 bucket
###########

resource "aws_s3_bucket" "vr_testing" {
  bucket = var.vrtesting_s3_screenshot_bucket_name
}

data "aws_canonical_user_id" "current" {}

resource "aws_s3_bucket_acl" "vr_testing_acl" {
  bucket = aws_s3_bucket.vr_testing.id
  access_control_policy {
    grant {
      grantee {
        id   = data.aws_canonical_user_id.current.id
        type = "CanonicalUser"
      }
      permission = "READ"
    }

    grant {
      grantee {
        type = "Group"
        uri  = "http://acs.amazonaws.com/groups/s3/LogDelivery"
      }
      permission = "READ_ACP"
    }

    owner {
      id = data.aws_canonical_user_id.current.id
    }
  }
}

output "ec2_global_ips" {
  value = ["${aws_instance.web.*.public_ip}"]
}
