#!/bin/bash
set -e

# Update and install required packages
apt-get update
apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    software-properties-common \
    snapd

# Install SSM Agent
snap install amazon-ssm-agent --classic
systemctl enable snap.amazon-ssm-agent.amazon-ssm-agent.service
systemctl start snap.amazon-ssm-agent.amazon-ssm-agent.service

# Install CloudWatch agent
wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
dpkg -i amazon-cloudwatch-agent.deb

# Configure CloudWatch agent
cat > /opt/aws/amazon-cloudwatch-agent/bin/config.json <<EOF
{
  "agent": {
    "run_as_user": "root"
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/syslog",
            "log_group_name": "${aws_cloudwatch_log_group}",
            "log_stream_name": "{instance_id}",
            "timezone": "UTC"
          },
          {
            "file_path": "/var/log/gitlab-runner/gitlab-runner.log",
            "log_group_name": "${aws_cloudwatch_log_group}",
            "log_stream_name": "{instance_id}-gitlab-runner",
            "timezone": "UTC"
          }
        ]
      }
    }
  }
}
EOF

# Start CloudWatch agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c file:/opt/aws/amazon-cloudwatch-agent/bin/config.json
systemctl enable amazon-cloudwatch-agent
systemctl start amazon-cloudwatch-agent

# Install Docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io

# Install Docker Machine
curl -L https://github.com/docker/machine/releases/download/v0.16.2/docker-machine-`uname -s`-`uname -m` >/tmp/docker-machine
chmod +x /tmp/docker-machine
mv /tmp/docker-machine /usr/local/bin/docker-machine

# Install GitLab runner
curl -L "https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.deb.sh" | bash
apt-get install gitlab-runner -y

# Add gitlab-runner user to docker group
usermod -aG docker gitlab-runner

# Create Docker daemon configuration
mkdir -p /etc/docker
cat > /etc/docker/daemon.json <<EOF
{
  "storage-driver": "overlay2",
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF

# Restart Docker to apply changes
systemctl restart docker

# Register the runner with docker+machine executor
gitlab-runner register \
  --non-interactive \
  --url "${gitlab_url}" \
  --registration-token "${gitlab_runner_token}" \
  --executor "docker+machine" \
  --docker-image "docker:latest" \
  --description "docker-machine-runner" \
  --tag-list "${runner_tags}" \
  --run-untagged="true" \
  --locked="false" \
  --access-level="not_protected" \
  --docker-privileged="true" \
  --machine-machine-driver "amazonec2" \
  --machine-machine-name "gitlab-docker-machine-%s" \
  --machine-machine-options "amazonec2-instance-type=t3.medium" \
  --machine-machine-options "amazonec2-region=${aws_region}" \
  --machine-machine-options "amazonec2-vpc-id=${vpc_id}" \
  --machine-machine-options "amazonec2-subnet-id=${subnet_id}" \
  --machine-machine-options "amazonec2-use-private-address=true" \
  --machine-machine-options "amazonec2-tags=runner-manager-name,gitlab-aws-autoscaler,gitlab,true,gitlab-runner-autoscale,true" \
  --machine-idle-nodes "1" \
  --machine-idle-time "1800" \
  --machine-max-builds "100" \
  --machine-min-available "0"

# Configure global runner settings
cat > /etc/gitlab-runner/config.toml <<EOF
concurrent = 10
check_interval = 0

[session_server]
  session_timeout = 1800

[[runners]]
  name = "docker-machine-runner"
  limit = 10
  output_limit = 4096
  executor = "docker+machine"
  [runners.docker]
    tls_verify = false
    image = "docker:latest"
    privileged = true
    disable_entrypoint_overwrite = false
    oom_kill_disable = false
    disable_cache = false
    shm_size = 0
  [runners.machine]
    IdleCount = 1
    IdleTime = 1800
    MaxBuilds = 100
    MachineDriver = "amazonec2"
    MachineName = "gitlab-docker-machine-%s"
    MachineOptions = [
      "amazonec2-instance-type=t3.medium",
      "amazonec2-region=${aws_region}",
      "amazonec2-vpc-id=${vpc_id}",
      "amazonec2-subnet-id=${subnet_id}",
      "amazonec2-use-private-address=true",
      "amazonec2-tags=runner-manager-name,gitlab-aws-autoscaler,gitlab,true,gitlab-runner-autoscale,true"
    ]
EOF

# Start the runner
gitlab-runner start

# Ensure services start on boot
systemctl enable docker
systemctl enable gitlab-runner