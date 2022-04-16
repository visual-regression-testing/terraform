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
  db_subnet_group_name      = var.vrtesting_rds_subnet_group
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

# this is not working
data "aws_db_snapshot" "latest_snapshot" {
  db_instance_identifier = aws_db_instance.visual_regression_rds_instance.id
  most_recent            = true
}

#
#data "aws_db_snapshot" "latest_prod_snapshot" {
#  db_instance_identifier = aws_db_instance.visual_regression_rds_instance.id
#  db_snapshot_identifier = var.vrtesting_rds_snapshot
#}

#########
# WEBSITE
#########

# todo need to update the env var
resource "aws_amplify_app" "website" {
  name       = "web-server"
  repository = "https://github.com/visual-regression-testing/web-server"

  # The default rewrites and redirects added by the Amplify Console.
  custom_rule {
    source = "/<*>"
    status = "404"
    target = "/index.html"
  }

  environment_variables = {
    ENV = var.website_auth_github_id
    ENV = var.website_auth_github_secret
  }
}

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
