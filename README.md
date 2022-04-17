Visual Regression Terraforming

## Introduction

This sets up the necessary infrastructure needed for visual regression testing

The AWS account needs to have access to 

- Amplify (service account)
- RDS
- S3
- IAM

## Testing

### Website

```terraform
terraform apply -target=aws_amplify_app.website -target=aws_amplify_branch.website_production -target=aws_iam_role.amplify_role -target=aws_iam_role_policy.amplify_role_policy
```

