variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "gitlab_url" {
  description = "GitLab instance URL"
  type        = string
}

variable "gitlab_runner_token" {
  description = "GitLab runner registration token"
  type        = string
  sensitive   = true
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

variable "instance_type" {
  description = "EC2 instance type for GitLab runner"
  type        = string
  default     = "t3.medium"
}

variable "business_hours_start" {
  description = "Business hours start time in UTC (Bangkok time - 7 hours)"
  type        = number
  default     = 2 # 9 AM Bangkok time (UTC+7) = 2 AM UTC
}

variable "business_hours_end" {
  description = "Business hours end time in UTC (Bangkok time - 7 hours)"
  type        = number
  default     = 11 # 6 PM Bangkok time (UTC+7) = 11 AM UTC
}

variable "runner_tags" {
  description = "Tags for the GitLab runner (comma-separated)"
  type        = string
  default     = "docker"
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "gitlab"
}

variable "service_name" {
  description = "Name of the service"
  type        = string
  default     = "gitlab-runners"
}

variable "cloudwatch_log_group_name" {
  description = "Name of the CloudWatch Log Group for GitLab runners"
  type        = string
  default     = "/gitlab-runner"
}

variable "asg_desired_capacity" {
  description = "Desired number of instances in the Auto Scaling Group"
  type        = number
  default     = 1
}

variable "asg_max_size" {
  description = "Maximum number of instances in the Auto Scaling Group"
  type        = number
  default     = 1
}

variable "asg_min_size" {
  description = "Minimum number of instances in the Auto Scaling Group"
  type        = number
  default     = 0
}
  