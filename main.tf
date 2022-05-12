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

variable "website_branch" {
  description = "The main GitHub branch and redirect URL"
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
resource "aws_amplify_app" "web_server" {
  name       = "web-server"
  repository = "https://github.com/visual-regression-testing/web-server"

  access_token = var.website_github_personal_or_oauth_token

  custom_rule {
    source = "/<*>"
    status = "404-200"
    target = "/index.html"
  }

  # todo find out how to not have to do this https://sreeraj.dev/setting-up-aws-amplify-for-a-next-js-ssr-app-with-terraform/
  # Comment this on the first run, trigger a build of your branch, This will added automatically on the console after deployment. Add it here to ensure your subsequent terraform runs don't break your amplify deployment.
  custom_rule {
    source = "/<*>"
    status = "200"
    target = "https://d2c3zynfrk5k2n.cloudfront.net/<*>"
  }

  iam_service_role_arn = aws_iam_role.amplify_role.arn

  enable_branch_auto_build    = true
  enable_branch_auto_deletion = true
}

resource "aws_amplify_branch" "website_production" {
  app_id      = aws_amplify_app.web_server.id
  branch_name = var.website_branch
  framework   = "Next.js - SSR"
  stage       = "PRODUCTION"

  environment_variables = {
    # deploy key is required because it needs a separate key for getting a (public) dependency via GitHub repo?
    DEPLOY_KEY = var.website_github_deploy_key

    # NextAuth
    NEXTAUTH_URL       = "https://${var.website_branch}.${aws_amplify_app.web_server.default_domain}"
    NEXT_PUBLIC_SECRET = var.website_nextauth_secret

    # GitHub app for authentication
    GITHUB_ID     = var.website_auth_github_id
    GITHUB_SECRET = var.website_auth_github_secret

    # Database connection
    MYSQL_HOST     = aws_db_instance.visual_regression_rds_instance.address
    MYSQL_DATABASE = aws_db_instance.visual_regression_rds_instance.name
    MYSQL_USERNAME = aws_db_instance.visual_regression_rds_instance.username
    MYSQL_PASSWORD = var.vrtesting_rds_password
    MYSQL_PORT     = aws_db_instance.visual_regression_rds_instance.port
  }
}

resource "aws_iam_role" "amplify_role" {
  name = "amplify_deploy_terraform_role"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "amplify.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy" "amplify_role_policy" {
  name = "amplify_iam_role_policy"
  role = aws_iam_role.amplify_role.id

  policy = file("${path.cwd}/amplify_role_policies.json")
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
