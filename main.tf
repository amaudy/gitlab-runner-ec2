provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      project_name = var.project_name
      service_name = var.service_name
      environment  = var.environment
    }
  }
}

# Create an IAM role for the GitLab runner
resource "aws_iam_role" "gitlab_runner" {
  name = "gitlab-runner-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# Create an IAM instance profile
resource "aws_iam_instance_profile" "gitlab_runner" {
  name = "gitlab-runner-${var.environment}"
  role = aws_iam_role.gitlab_runner.name
}

# Security group for GitLab runner
resource "aws_security_group" "gitlab_runner" {
  name        = "gitlab-runner-${var.environment}"
  description = "Security group for GitLab runner"
  vpc_id      = data.aws_vpc.default.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "gitlab-runner-${var.environment}"
    Environment = var.environment
  }
}

# Launch template for GitLab runner - remove public IP
resource "aws_launch_template" "gitlab_runner" {
  name_prefix   = "gitlab-runner-${var.environment}"
  image_id      = data.aws_ami.ami.id
  instance_type = var.instance_type

  monitoring {
    enabled = true # Enable detailed monitoring
  }

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [aws_security_group.gitlab_runner.id]
  }

  iam_instance_profile {
    name = aws_iam_instance_profile.gitlab_runner.name
  }

  user_data = base64encode(templatefile("${path.module}/scripts/user_data.sh", {
    gitlab_url               = var.gitlab_url
    gitlab_runner_token      = var.gitlab_runner_token
    runner_tags              = var.runner_tags
    aws_cloudwatch_log_group = aws_cloudwatch_log_group.gitlab_runner.name
    aws_region               = var.aws_region
    vpc_id                   = data.aws_vpc.default.id
    subnet_id                = data.aws_subnets.private.ids[0]
  }))

  tags = {
    Name      = "gitlab-runner-${var.environment}"
    Timestamp = timestamp()
  }
}

# Auto Scaling Group
resource "aws_autoscaling_group" "gitlab_runner" {
  name                = "gitlab-runner-${var.environment}"
  desired_capacity    = var.asg_desired_capacity
  max_size            = var.asg_max_size
  min_size            = var.asg_min_size
  target_group_arns   = []
  vpc_zone_identifier = data.aws_subnets.private.ids

  launch_template {
    id      = aws_launch_template.gitlab_runner.id
    version = "$Latest"
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
  }

  dynamic "tag" {
    for_each = merge(
      {
        "Name" = "gitlab-runner-${var.environment}"
      },
      {
        "project_name" = var.project_name
        "service_name" = var.service_name
        "environment"  = var.environment
      }
    )
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }
}

# Schedule for scaling down during non-business hours
resource "aws_autoscaling_schedule" "scale_down" {
  scheduled_action_name  = "scale-down"
  min_size              = 0
  max_size              = 0
  desired_capacity      = 0
  recurrence            = "0 13 * * MON-FRI"  # 20:00 Bangkok time
  autoscaling_group_name = aws_autoscaling_group.gitlab_runner.name
}

# Schedule for scaling up during business hours
resource "aws_autoscaling_schedule" "scale_up" {
  scheduled_action_name  = "scale-up"
  min_size              = var.asg_min_size
  max_size              = var.asg_max_size
  desired_capacity      = var.asg_desired_capacity
  recurrence            = "30 1 * * MON-FRI"  # 08:30 Bangkok time
  autoscaling_group_name = aws_autoscaling_group.gitlab_runner.name
}

# Create NAT Gateway
resource "aws_eip" "nat" {
  domain = "vpc"
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = data.aws_subnets.public.ids[0]

  tags = {
    Name = "gitlab-runner-nat-${var.environment}"
  }
}

# Create route table for private subnets
resource "aws_route_table" "private" {
  vpc_id = data.aws_vpc.default.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name = "gitlab-runner-private-${var.environment}"
  }
}

# Associate private subnets with the route table
resource "aws_route_table_association" "private" {
  count          = length(data.aws_subnets.private.ids)
  subnet_id      = data.aws_subnets.private.ids[count.index]
  route_table_id = aws_route_table.private.id
}

# Create CloudWatch Logs policy
resource "aws_iam_role_policy" "cloudwatch_logs" {
  name = "gitlab-runner-cloudwatch-logs-${var.environment}"
  role = aws_iam_role.gitlab_runner.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = ["arn:aws:logs:*:*:*"]
      }
    ]
  })
}

# Create CloudWatch Log Group
resource "aws_cloudwatch_log_group" "gitlab_runner" {
  name              = "${var.cloudwatch_log_group_name}/${var.environment}"
  retention_in_days = 7

  tags = {
    Name = "gitlab-runner-${var.environment}"
  }
}

# Add Session Manager policy to the IAM role
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.gitlab_runner.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Add CloudWatch monitoring policy to the IAM role
resource "aws_iam_role_policy_attachment" "cloudwatch_monitoring" {
  role       = aws_iam_role.gitlab_runner.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}
