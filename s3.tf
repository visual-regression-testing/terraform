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


