# GitLab Runners Private

## Overview

This Terraform code creates a GitLab runner on AWS EC2.

- Use EC2 instance to host the runner.
- The EC2 will launch in private subnets. Not exposed to the public internet.
- The EC2 also be able to use SSM to connect to the instance.
- The EC2 instance size is defined in `terraform.tfvars` file.
- Use IAM role and instance profile to manage permissions.
- Autoscale the runner to 3 instances during business hours.
- Scale to 0 instances when outside business hours.
- Business hours are defined in `terraform.tfvars` file.
- The runner tags are defined in `terraform.tfvars` file.
- Use CloudWatch to monitor the runner.

## Prerequisites

- Terraform CLI
- AWS CLI
- GitLab Runner token

## Architecture

![Architecture](./images/gitlab-runner-ec2-autoscale.png)

## IAM

The file `terraform-gitlab-runner-policy.json` will guide you to create the IAM policy for this project.

## Usage

The Gitlab URL and runner token can be found in the Gitlab instance under `Settings > CI / CD > Runners settings`.

Don't put the runner token in the `terraform.tfvars` file. Use the `-var` flag to set the runner token and store token in environment variable.

1. Set the environment variables.
2. Run `terraform init`.
3. Run `terraform plan -var="gitlab_url=xxxxx" -var="gitlab_runner_token=xxxxx" -out=tfplan`.
4. Run `terraform apply tfplan`.

## Variables

- `aws_region`: AWS region.
- `environment`: Environment name.
- `instance_type`: EC2 instance type.
- `business_hours_start`: Business hours start time (GMT).
- `business_hours_end`: Business hours end time (GMT).
- `gitlab_url`: GitLab instance URL.
- `gitlab_runner_token`: GitLab runner registration token.
- `runner_tags`: Runner tags.
- `cloudwatch_log_group_name`: CloudWatch log group name.
