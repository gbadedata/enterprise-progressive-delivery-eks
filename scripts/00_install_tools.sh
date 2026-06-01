#!/usr/bin/env bash
set -euo pipefail

echo "Updating Ubuntu packages..."
sudo apt update -y
sudo apt upgrade -y

echo "Installing base packages..."
sudo apt install -y \
  curl \
  wget \
  unzip \
  git \
  jq \
  ca-certificates \
  gnupg \
  lsb-release \
  software-properties-common \
  apt-transport-https

echo "Installing AWS CLI v2..."
if ! command -v aws >/dev/null 2>&1; then
  cd /tmp
  curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
  unzip -q awscliv2.zip
  sudo ./aws/install
else
  echo "AWS CLI already installed."
fi

echo "Installing kubectl..."
if ! command -v kubectl >/dev/null 2>&1; then
  curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
  chmod +x kubectl
  sudo mv kubectl /usr/local/bin/kubectl
else
  echo "kubectl already installed."
fi

echo "Installing Terraform..."
if ! command -v terraform >/dev/null 2>&1; then
  wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | \
    sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg >/dev/null

  echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
    sudo tee /etc/apt/sources.list.d/hashicorp.list

  sudo apt update -y
  sudo apt install -y terraform
else
  echo "Terraform already installed."
fi

echo "Installing Helm..."
if ! command -v helm >/dev/null 2>&1; then
  curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
else
  echo "Helm already installed."
fi

echo "Installing eksctl..."
if ! command -v eksctl >/dev/null 2>&1; then
  curl --silent --location \
    "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" \
    | tar xz -C /tmp

  sudo mv /tmp/eksctl /usr/local/bin/eksctl
else
  echo "eksctl already installed."
fi

echo "Installing Docker..."
if ! command -v docker >/dev/null 2>&1; then
  sudo apt install -y docker.io
  sudo systemctl enable docker
  sudo systemctl start docker
  sudo usermod -aG docker "$USER"
else
  echo "Docker already installed."
fi

echo "Installing Node.js 20..."
if ! command -v node >/dev/null 2>&1; then
  curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
  sudo apt install -y nodejs
else
  echo "Node.js already installed."
fi

echo "Installing Trivy..."
if ! command -v trivy >/dev/null 2>&1; then
  sudo apt install -y wget apt-transport-https gnupg lsb-release
  wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | \
    gpg --dearmor | sudo tee /usr/share/keyrings/trivy.gpg >/dev/null

  echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" | \
    sudo tee /etc/apt/sources.list.d/trivy.list

  sudo apt update -y
  sudo apt install -y trivy
else
  echo "Trivy already installed."
fi

echo "Installing Checkov..."
if ! command -v checkov >/dev/null 2>&1; then
  sudo apt install -y python3-pip python3-venv
  python3 -m venv "$HOME/.venvs/checkov"
  "$HOME/.venvs/checkov/bin/pip" install --upgrade pip
  "$HOME/.venvs/checkov/bin/pip" install checkov
  sudo ln -sf "$HOME/.venvs/checkov/bin/checkov" /usr/local/bin/checkov
else
  echo "Checkov already installed."
fi

echo "Installing kubeconform..."
if ! command -v kubeconform >/dev/null 2>&1; then
  KUBECONFORM_VERSION="v0.6.7"
  cd /tmp
  curl -L -o kubeconform.tar.gz \
    "https://github.com/yannh/kubeconform/releases/download/${KUBECONFORM_VERSION}/kubeconform-linux-amd64.tar.gz"
  tar -xzf kubeconform.tar.gz
  sudo mv kubeconform /usr/local/bin/kubeconform
else
  echo "kubeconform already installed."
fi

echo "Tool installation complete."
echo "Important: if Docker was newly installed, close this terminal and reopen it before using docker without sudo."
