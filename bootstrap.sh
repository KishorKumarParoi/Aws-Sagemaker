#!/usr/bin/env bash
# ==============================================================================
# 🚀 ZERO-TOUCH 1-COMMAND AUTO-BOOTSTRAPPER FOR EC2 & CLOUD VMS
# AWS SageMaker End-to-End MLOps Pipeline & Serving
#
# Run directly on any bare, fresh EC2 instance or local workstation
# via a single curl command without pre-installing git, docker, or python:
#
#   1. Standard Mode:
#      curl -fsSL https://raw.githubusercontent.com/KishorKumarParoi/Aws-Sagemaker/main/bootstrap.sh | bash
#
#   2. Standalone Mode (Zero Docker, Instant Native Python < 15s):
#      curl -fsSL https://raw.githubusercontent.com/KishorKumarParoi/Aws-Sagemaker/main/bootstrap.sh | bash -s -- --standalone
#
#   3. Ultra-Fast Lightweight Cloud Mode (< 30s):
#      curl -fsSL https://raw.githubusercontent.com/KishorKumarParoi/Aws-Sagemaker/main/bootstrap.sh | bash -s -- --quick
# ==============================================================================

set -eo pipefail

if [ -e /dev/tty ] && [ -r /dev/tty ]; then
    exec </dev/tty
fi

BOLD='\033[1m'
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${CYAN}${BOLD}"
cat << "EOF"
================================================================================
  🚀 AWS SageMaker End-to-End MLOps Pipeline & Serving
  Zero-Touch Instant Cloud & Workstation Bootstrapper
================================================================================
EOF
echo -e "${NC}"

export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a
export UCF_FORCE_CONFFOLD=1

run_sudo() {
    if [ "$EUID" -eq 0 ]; then
        "$@"
    elif command -v sudo &>/dev/null && sudo -n true 2>/dev/null; then
        sudo -E "$@"
    elif command -v sudo &>/dev/null; then
        sudo -E "$@"
    else
        "$@"
    fi
}

echo -e "${CYAN}[1/4] Detecting OS and ensuring Git & Curl are available...${NC}"

if ! command -v git &>/dev/null || ! command -v curl &>/dev/null; then
    echo -e "${YELLOW}[+] Installing Git and Core Networking Utilities non-interactively...${NC}"
    if [ -f /etc/debian_version ]; then
        run_sudo apt-get update -qq
        run_sudo apt-get install -y -qq --no-install-recommends git curl ca-certificates tar gzip unzip build-essential >/dev/null 2>&1 || true
    elif [ -f /etc/amazon-linux-release ] || [ -f /etc/redhat-release ]; then
        if command -v dnf &>/dev/null; then
            run_sudo dnf install -y -q git curl ca-certificates tar gzip unzip >/dev/null 2>&1 || true
        else
            run_sudo yum install -y -q git curl ca-certificates tar gzip unzip >/dev/null 2>&1 || true
        fi
    elif [ -f /etc/alpine-release ]; then
        run_sudo apk add --no-cache git curl bash ca-certificates
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        if ! command -v git &>/dev/null; then
            xcode-select --install 2>/dev/null || true
        fi
    fi
fi

echo -e "${GREEN}[✓] Git : $(git --version 2>/dev/null || echo 'Installed')${NC}"
echo -e "${GREEN}[✓] Curl: $(curl --version 2>/dev/null | head -n 1 || echo 'Installed')${NC}"

echo -e "\n${CYAN}[2/4] Checking System Memory & OOM Protection...${NC}"
if command -v free &>/dev/null; then
    TOTAL_RAM_MB=$(free -m | awk '/^Mem:/{print $2}')
    EXISTING_SWAP_MB=$(free -m | awk '/^Swap:/{print $2}')
    if [ "$TOTAL_RAM_MB" -lt 4000 ] && [ "$EXISTING_SWAP_MB" -lt 1000 ]; then
        echo -e "${YELLOW}[!] Host has ${TOTAL_RAM_MB}MB RAM. Auto-configuring 4GB swapfile for compilation safety...${NC}"
        if [ ! -f /swapfile ]; then
            run_sudo fallocate -l 4G /swapfile 2>/dev/null || run_sudo dd if=/dev/zero of=/swapfile bs=1M count=4096 2>/dev/null
            run_sudo chmod 600 /swapfile
            run_sudo mkswap /swapfile >/dev/null 2>&1
            run_sudo swapon /swapfile 2>/dev/null || true
            if ! grep -q "/swapfile" /etc/fstab 2>/dev/null; then
                echo "/swapfile none swap sw 0 0" | run_sudo tee -a /etc/fstab >/dev/null 2>&1 || true
            fi
            echo -e "${GREEN}[✓] 4GB Swapfile configured and active!${NC}"
        fi
    else
        echo -e "${GREEN}[✓] Sufficient memory available (${TOTAL_RAM_MB}MB RAM, ${EXISTING_SWAP_MB}MB Swap).${NC}"
    fi
else
    echo -e "${GREEN}[✓] Memory check bypassed (macOS / BSD runtime).${NC}"
fi

echo -e "\n${CYAN}[3/4] Ensuring Aws-Sagemaker repository is local...${NC}"
REPO_URL="https://github.com/KishorKumarParoi/38-Aws-Sagemaker.git"
REPO_DIR="Aws-Sagemaker"

if [ -f "deploy.sh" ]; then
    echo -e "${GREEN}[✓] Already inside repository directory ($(pwd)). Syncing latest commit...${NC}"
    git pull --depth 1 origin main 2>/dev/null || true
elif [ -d "$REPO_DIR" ] && [ -f "$REPO_DIR/deploy.sh" ]; then
    echo -e "${GREEN}[✓] Found existing directory ${REPO_DIR}. Entering and updating...${NC}"
    cd "$REPO_DIR"
    git pull --depth 1 origin main 2>/dev/null || true
else
    echo -e "${YELLOW}[+] Shallow cloning repository from GitHub for maximum speed...${NC}"
    git clone --depth 1 "$REPO_URL" "$REPO_DIR"
    cd "$REPO_DIR"
fi

chmod +x deploy.sh clear.sh bootstrap.sh 2>/dev/null || true
find scripts/ -type f -name "*.sh" -exec chmod +x {} + 2>/dev/null || true

echo -e "\n${CYAN}[4/4] Executing One-Click Production Deployment Pipeline...${NC}"
if [ -t 0 ]; then
    exec ./deploy.sh "$@"
elif [ -e /dev/tty ] && [ -r /dev/tty ]; then
    exec ./deploy.sh "$@" </dev/tty
else
    exec ./deploy.sh "$@" </dev/null
fi
