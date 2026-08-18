#!/bin/bash

set -euxo pipefail

echo "======================================"
echo "Starting Bastion Host Bootstrap"
echo "======================================"


# ----------------------------------------
# Update system
# ----------------------------------------

dnf update -y


# ----------------------------------------
# Install required packages
# ----------------------------------------
# Amazon Linux 2023 already provides
# curl-minimal, so DO NOT install curl.

dnf install -y \
    unzip \
    git \
    jq \
    tar \
    gzip \
    ca-certificates \
    docker


# ----------------------------------------
# Start Docker
# ----------------------------------------

systemctl enable docker
systemctl start docker


# ----------------------------------------
# Add ec2-user to Docker group
# ----------------------------------------

usermod -aG docker ec2-user


# ----------------------------------------
# AWS CLI v2
# ----------------------------------------

if ! command -v aws >/dev/null 2>&1; then

    echo "Installing AWS CLI..."

    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" \
        -o /tmp/awscliv2.zip

    unzip -q /tmp/awscliv2.zip -d /tmp

    /tmp/aws/install

else

    echo "AWS CLI already installed."

fi


# ----------------------------------------
# kubectl
# ----------------------------------------

if ! command -v kubectl >/dev/null 2>&1; then

    echo "Installing kubectl..."

    KUBECTL_VERSION=$(curl -L -s \
        https://dl.k8s.io/release/stable.txt)

    curl -LO \
        "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"

    chmod +x kubectl

    mv kubectl /usr/local/bin/kubectl

else

    echo "kubectl already installed."

fi


# ----------------------------------------
# Helm
# ----------------------------------------

if ! command -v helm >/dev/null 2>&1; then

    echo "Installing Helm..."

    curl -fsSL \
        https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 \
        | bash

else

    echo "Helm already installed."

fi


# ----------------------------------------
# eksctl
# ----------------------------------------

if ! command -v eksctl >/dev/null 2>&1; then

    echo "Installing eksctl..."

    ARCH=$(uname -m)

    if [ "$ARCH" = "x86_64" ]; then
        EKSCTL_ARCH="amd64"
    elif [ "$ARCH" = "aarch64" ]; then
        EKSCTL_ARCH="arm64"
    else
        echo "Unsupported architecture: $ARCH"
        exit 1
    fi

    curl --silent --location \
        "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_Linux_${EKSCTL_ARCH}.tar.gz" \
        | tar xz -C /tmp

    mv /tmp/eksctl /usr/local/bin/eksctl

else

    echo "eksctl already installed."

fi


# ----------------------------------------
# AWS Systems Manager Agent
# ----------------------------------------

echo "Checking SSM Agent..."

if command -v systemctl >/dev/null 2>&1; then

    systemctl enable amazon-ssm-agent || true
    systemctl start amazon-ssm-agent || true

fi


# ----------------------------------------
# Clean temporary files
# ----------------------------------------

rm -rf /tmp/aws
rm -rf /tmp/awscliv2.zip
rm -rf /tmp/eksctl


# ----------------------------------------
# Verify installations
# ----------------------------------------

echo ""
echo "======================================"
echo "Installed Versions"
echo "======================================"

echo ""
echo "AWS CLI:"
aws --version

echo ""
echo "kubectl:"
kubectl version --client

echo ""
echo "Helm:"
helm version --short

echo ""
echo "eksctl:"
eksctl version

echo ""
echo "Git:"
git --version

echo ""
echo "Docker:"
docker --version

echo ""
echo "======================================"
echo "Bastion Bootstrap Completed"
echo "======================================"