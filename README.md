# Fully Automated EC2 Instance Setup with Docker, Nginx, and GitLab CI/CD Pipeline #

  ## GitLab CI Pipeline

The .gitlab-ci.yml file defines a GitLab CI pipeline with the following stages:

    Build: Builds the Docker image for the application.
    Lint: Lints the application code to ensure code quality.
    Test: Runs tests on the application.
    Deploy: Deploys the Docker container on the EC2 instance.

The CI pipeline's runtime and detailed logs can be found [here](https://gitlab.com/eldahroug/devops-tmdb/-/pipelines).

  ## Terraform Automated EC2 Instance Setup with Docker, Nginx, and GitLab Runner

## Overview

This Terraform configuration automates the deployment of an AWS EC2 instance configured to run Docker, Nginx, and a GitLab Runner. The setup leverages AWS Systems Manager Parameter Store to securely manage sensitive information such as tokens required for GitLab CI/CD operations.

## Features

- Launches an EC2 instance with the specified AMI and instance type.
- Attaches the instance to an IAM role with the necessary policies to access AWS Systems Manager Parameter Store.
- Installs Docker and dependencies required to host the application.
- Installs GitLab Runner and registers it to a specified GitLab project.
- Triggers a GitLab CI pipeline to build and push the application Docker image.
- Deploys the application using Docker and Nginx.

## Prerequisites

- AWS account with appropriate permissions to create EC2 instances, IAM roles, policies, and access to Systems Manager Parameter Store.
- Pre-configured key pair in AWS for SSH access.
- GitLab account and project with CI/CD pipeline configured.

## Setup Instructions

1. **Clone the Repository:**
   ```sh
   git clone https://github.com/eldahroug/tmdb-devops-challenge.git
   cd tmdb-devops-challenge

2. **Configure Terraform:**

Update the tmdb-iac.tf file with your specific configurations such as AMI ID, instance type, and key pair name.

3. **Store Tokens in AWS SSM:**

Store the `REGISTRATION_TOKEN` and `PIPELINE_TRIGGER_TOKEN` in AWS Systems Manager Parameter Store.
```sh
aws ssm put-parameter --name "REGISTRATION_TOKEN" --value "your-registration-token" --type "SecureString"
aws ssm put-parameter --name "PIPELINE_TRIGGER_TOKEN" --value "your-pipeline-trigger-token" --type "SecureString"
```

4. ***Apply Terraform Configuration:***
Initialize Terraform and apply the configuration.
```sh
terraform init
terraform apply
```

5. **Verify Deployment**

Once the Terraform apply process completes, verify that the EC2 instance is running, Docker and Nginx are installed, and the GitLab Runner is registered for any future commits actions on the main branch. Additionally, verify that the GitLab CI pipeline was triggered and successfully ran. You can access the running application by navigating to http://<node_ip> in your web browser.


## Secure Handling of Secrets

    AWS Systems Manager Parameter Store (SSM):
        Sensitive values such as REGISTRATION_TOKEN and PIPELINE_TRIGGER_TOKEN are stored in the SSM Parameter Store.
        These values are retrieved securely during the user data script execution, ensuring that they are not hard-coded in the script or Terraform configuration.


******Security Considerations******
-  *Parameter Store:*
    -  Sensitive information such as tokens are stored securely in AWS Systems Manager Parameter Store.
    -  Ensure that access to these parameters is restricted to necessary roles and users only.



- *IAM Policies:*
  -  The IAM policies attached to the EC2 instance role are scoped to the minimum permissions required for the setup.    
