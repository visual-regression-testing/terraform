terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.27"
    }
  }

  required_version = ">= 0.14.9"
}

provider "aws" {
  profile = "default"
  region  = "us-east-1"
}

variable "vrtesting_aws_rds_username" {
  description = "The username for the DB master user"
  type        = string
}

variable "vrtesting_aws_rds_password" {
  description = "The password for the DB master user"
  type        = string
}

variable "vrtesting_rds_snapshot_id" {
  description = "The name of the RDS snapshot"
  type        = string
}

variable "vrtesting_s3_screenshot_bucket_name" {
  description = "The bucket for storing comparison images"
  type        = string
}


resource "aws_db_instance" "visual_regression_rds_instance" {
  engine                    = "mysql"
  engine_version            = "5.7"
  instance_class            = "db.t3.micro"
  username                  = var.vrtesting_aws_rds_username
  password                  = var.vrtesting_aws_rds_password
  parameter_group_name      = "default.mysql8.0"
  snapshot_identifier       = var.vrtesting_rds_snapshot_id
  final_snapshot_identifier = var.vrtesting_rds_snapshot_id
}

data "aws_db_snapshot" "latest_prod_snapshot" {
  db_instance_identifier = aws_db_instance.visual_regression_rds_instance.id
  most_recent            = true
  db_snapshot_identifier = var.vrtesting_rds_snapshot_id
}

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
