# AWS
aws_region  = "us-east-1"
environment = "dev"

# Auto Scaling
instance_type        = "t3.xlarge"
business_hours_start = 1.5 # 08:30 Bangkok time
business_hours_end   = 13  # 20:00 Bangkok time
asg_desired_capacity = 3
asg_max_size         = 3
asg_min_size         = 0

# Tags
project_name = "gitlab"
service_name = "runners"

# Runner
runner_tags = "docker,aws,dev"

# CloudWatch
cloudwatch_log_group_name = "/aws/ec2/runners"
