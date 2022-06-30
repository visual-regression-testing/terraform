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
    GITHUB_ID       = "${var.website_auth_github_id}"
    GITHUB_SECRET   = "${var.website_auth_github_secret}"
    NEXTAUTH_SECRET = "${var.website_nextauth_secret}"
  }
}

## todo Launch RDS into VCS - RDS is above ^^^
## todo should RDS use or go off migration (not important for initial deployment test)

output "ec2_global_ips" {
  value = ["${aws_instance.web.*.public_ip}"]
}
