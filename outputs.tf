output "ami_id" {
  description = "The ID of the AMI used for GitLab runners"
  value       = data.aws_ami.ami.id
}

output "ami_name" {
  description = "The name of the AMI used for GitLab runners"
  value       = data.aws_ami.ami.name
}

output "cloudwatch_log_group" {
  description = "The CloudWatch Log Group name for GitLab runners"
  value       = aws_cloudwatch_log_group.gitlab_runner.name
}

output "asg_name" {
  description = "The name of the Auto Scaling Group"
  value       = aws_autoscaling_group.gitlab_runner.name
} 