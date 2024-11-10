terraform {
  backend "s3" {
    bucket         = "YOUR_S3_BUCKET_NAME"
    key            = "gitlab-runner/terraform.tfstate"
    region         = "YOUR_AWS_REGION"
    encrypt        = true
    dynamodb_table = "terraform-gitlab-runner-state-lock" # Optional
  }
} 