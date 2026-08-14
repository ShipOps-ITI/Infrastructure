#!/bin/bash
set -eux

# Update system packages and install the tools needed for cluster operations
sudo dnf update -y
sudo dnf install -y \
  unzip \
  git \
  jq \
  curl \
  tar \
  gzip

# Ensure the AWS Systems Manager agent is enabled and running
sudo systemctl enable amazon-ssm-agent
sudo systemctl start amazon-ssm-agent || true

# Install AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
unzip -q /tmp/awscliv2.zip -d /tmp
sudo /tmp/aws/install

# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/kubectl

# Install Helm
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Verify tools are available
aws --version
kubectl version --client
helm version --short
