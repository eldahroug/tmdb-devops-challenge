provider "aws" {
  region = "us-east-2"
}

# Define AWS security group
resource "aws_security_group" "instance" {
  name        = "terraform-example-instance"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Define IAM role for SSM access
resource "aws_iam_role" "ssm_role" {
  name = "ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# Define IAM policy for SSM access
resource "aws_iam_policy" "ssm_policy" {
  name        = "ssm-policy"
  description = "Policy to allow access to SSM Parameter Store"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath"
        ],
        Resource = "*"
      }
    ]
  })
}

# Attach IAM policy to IAM role
resource "aws_iam_role_policy_attachment" "ssm_role_attachment" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = aws_iam_policy.ssm_policy.arn
}

# Define IAM instance profile for EC2 instance
resource "aws_iam_instance_profile" "ssm_instance_profile" {
  name = "ssm-instance-profile"
  role = aws_iam_role.ssm_role.name
}

# Define EC2 instance
resource "aws_instance" "example" {
  ami                    = "ami-0fb653ca2d3203ac1"
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.instance.id]

  iam_instance_profile = aws_iam_instance_profile.ssm_instance_profile.name

  user_data = <<-EOF
    #!/bin/bash
    set -e

    # Log file for debugging
    exec > /var/log/user-data.log 2>&1

    echo "Script started."
    
    # Install necessary dependencies
    echo "Installing necessary dependencies..."
    sudo apt-get update -y
    sudo apt-get install -y curl ca-certificates gnupg lsb-release unzip


    # Install AWS CLI
    echo "Installing AWS CLI..."
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    sudo ./aws/install

    # Install Docker
    echo "Installing Docker..."
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo \
      "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io

    sudo usermod -aG docker ubuntu
    sudo systemctl enable docker
    sudo systemctl start docker

    # Install GitLab Runner manually
    echo "Installing GitLab Runner manually..."
    sudo curl -L --output /usr/local/bin/gitlab-runner https://gitlab-runner-downloads.s3.amazonaws.com/latest/binaries/gitlab-runner-linux-amd64
    sudo chmod +x /usr/local/bin/gitlab-runner
    sudo useradd --comment 'GitLab Runner' --create-home gitlab-runner --shell /bin/bash
    sudo gitlab-runner install --user=gitlab-runner --working-directory=/home/gitlab-runner
    sudo gitlab-runner start

    # Ensure the GitLab runner user owns its home directory
    echo "Ensuring proper permissions for GitLab runner user..."
    sudo chown -R gitlab-runner:gitlab-runner /home/gitlab-runner/
    sudo usermod -aG docker gitlab-runner

    # Variables for GitLab Runner
    GITLAB_URL="https://gitlab.com/"
    RUNNER_NAME="shell"
    REGISTRATION_TOKEN="$(aws ssm get-parameter --name 'REGISTRATION_TOKEN' --with-decryption --query 'Parameter.Value' --output text)"
    RUNNER_TAGS="shell"
    RUNNER_EXECUTOR="shell"
    RUNNER_SHELL="bash"

    # Optional: Fix for clear_console issue in .bash_logout
    echo "Fixing potential clear_console issue in .bash_logout..."
    BASH_LOGOUT="/home/gitlab-runner/.bash_logout"
    if grep -q "clear_console" "$BASH_LOGOUT"; then
      sudo sed -i 's/^if \[ "\$SHLVL" = 1 \]; then$/#&/' "$BASH_LOGOUT"
      sudo sed -i 's/^\s*\[ -x \/usr\/bin\/clear_console \] && \/usr\/bin\/clear_console -q$/#&/' "$BASH_LOGOUT"
      sudo sed -i 's/^fi$/#&/' "$BASH_LOGOUT"
    fi

    # Register the GitLab Runner
    echo "Registering the GitLab Runner..."
    sudo gitlab-runner register --non-interactive \
      --url "$GITLAB_URL" \
      --registration-token "$REGISTRATION_TOKEN" \
      --name "$RUNNER_NAME" \
      --executor "$RUNNER_EXECUTOR" \
      --shell "$RUNNER_SHELL" \
      --tag-list "$RUNNER_TAGS"

    # Run GitLab CI pipeline
    echo "Triggering GitLab CI pipeline..."
    PIPELINE_TRIGGER_URL="https://gitlab.com/api/v4/projects/59432361/trigger/pipeline"
    PIPELINE_TRIGGER_TOKEN="$(aws ssm get-parameter --name 'PIPELINE_TRIGGER_TOKEN' --with-decryption --query 'Parameter.Value' --output text)"
    curl -X POST -F token=$PIPELINE_TRIGGER_TOKEN -F ref=main $PIPELINE_TRIGGER_URL

    # Wait for the pipeline to complete
    echo "Waiting for the pipeline to complete..."
    sleep 420  # Adjust this as needed

    # Remove any existing Docker container on port 3000
    echo "Removing any existing Docker container on port 3000..."
    CONTAINER_ID=$(sudo docker ps -q --filter "ancestor=tmdb-devops-challenge")
    if [ -n "$CONTAINER_ID" ]; then
      sudo docker stop $CONTAINER_ID
      sudo docker rm $CONTAINER_ID
    fi

    # Create Docker Compose file for Nginx and the application container
    echo "Creating Docker Compose file..."
    cat <<EOL > /home/ubuntu/docker-compose.yml
    version: '3'
    services:
      nginx:
        image: nginx:latest
        ports:
          - "80:80"
        volumes:
          - ./nginx.conf:/etc/nginx/conf.d/default.conf
        depends_on:
          - app
      app:
        image: tmdb-devops-challenge
        ports:
          - "3000:3000"
    EOL

    # Create Nginx configuration file
    echo "Creating Nginx configuration file..."
    cat <<EOL > /home/ubuntu/nginx.conf
    server {
        listen 80;
        location / {
            proxy_pass http://app:3000/;
        }
    }
    EOL

    # Start Docker Compose
    echo "Starting Docker Compose..."
    cd /home/ubuntu
    sudo docker compose up -d

    echo "Setup completed successfully."
  EOF

  user_data_replace_on_change = true

  key_name = "test" # Replace with your existing key pair name

  tags = {
    Name = "terraform-example"
  }
}