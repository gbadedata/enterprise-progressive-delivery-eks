#!/usr/bin/env bash
set -euo pipefail

echo "Checking installed tools..."
echo

check_tool() {
  local tool_name="$1"
  local version_command="$2"

  if command -v "$tool_name" >/dev/null 2>&1; then
    echo "OK: $tool_name found"
    bash -c "$version_command" || true
    echo
  else
    echo "MISSING: $tool_name"
    exit 1
  fi
}

check_tool "git" "git --version"
check_tool "aws" "aws --version"
check_tool "kubectl" "kubectl version --client=true"
check_tool "terraform" "terraform version"
check_tool "helm" "helm version --short"
check_tool "eksctl" "eksctl version"
check_tool "docker" "docker --version"
check_tool "node" "node --version"
check_tool "npm" "npm --version"
check_tool "trivy" "trivy --version"
check_tool "checkov" "checkov --version"
check_tool "kubeconform" "kubeconform -v"

echo "All required tools are installed."
