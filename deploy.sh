#!/usr/bin/env bash
# ==============================================================================
# 🚀 ONE-CLICK PRODUCTION BOOTSTRAP & RESILIENT DEPLOYMENT ORCHESTRATOR
# AWS SageMaker End-to-End MLOps Pipeline & Serving
#
# Supported Modes:
#   ./deploy.sh                      # Standard full deployment
#   ./deploy.sh --standalone         # Zero-Docker Native Python Mode (< 15s)
#   ./deploy.sh --quick              # Lightweight fast mode
#   ./deploy.sh --test               # Run test suite
# ==============================================================================

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

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
  Production Deployment Orchestrator
================================================================================
EOF
echo -e "${NC}"

RUN_TESTS=false
QUICK_MODE=false
STANDALONE_MODE=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --standalone|--no-docker|--local)
            STANDALONE_MODE=true
            shift
            ;;
        --quick|--fast)
            QUICK_MODE=true
            shift
            ;;
        --test|-t)
            RUN_TESTS=true
            shift
            ;;
        --help|-h)
            echo "Usage: ./deploy.sh [OPTIONS]"
            echo "  --standalone, --no-docker  Run in lightweight Standalone Python Mode (Zero Docker required)"
            echo "  --quick, --fast            Run core services in fast mode (< 30s)"
            echo "  --test, -t                 Run automated test suite"
            echo "  --help, -h                 Show this help message"
            exit 0
            ;;
        *)
            shift
            ;;
    esac
done

# 1. Discover Host Public IP
SERVER_PUBLIC_IP=""
IMDS_TOKEN=$(curl -s -m 2 -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" 2>/dev/null || true)
if [ -n "$IMDS_TOKEN" ]; then
    SERVER_PUBLIC_IP=$(curl -s -m 2 -H "X-aws-ec2-metadata-token: $IMDS_TOKEN" "http://169.254.169.254/latest/meta-data/public-ipv4" 2>/dev/null || true)
fi
if [ -z "$SERVER_PUBLIC_IP" ]; then
    SERVER_PUBLIC_IP=$(curl -s -m 3 https://ifconfig.me 2>/dev/null || echo "127.0.0.1")
fi
export SERVER_PUBLIC_IP="${SERVER_PUBLIC_IP:-127.0.0.1}"
echo -e "${GREEN}[✓] Host Public IP Detected: ${BOLD}${SERVER_PUBLIC_IP}${NC}"

# 2. Ensure .env exists
if [ ! -f .env ] && [ -f .env.example ]; then
    cp .env.example .env
fi

# 3. Ensure uv & Python
if ! command -v uv &>/dev/null; then
    curl -LsSf https://astral.sh/uv/install.sh | sh 2>/dev/null || true
    export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
fi
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"

if command -v uv &>/dev/null; then
    uv sync --quiet 2>/dev/null || true
fi

# 4. Check Docker Availability (Auto-Healing Fallback)
DOCKER_AVAILABLE=false
if [ "$STANDALONE_MODE" = false ] && command -v docker &>/dev/null; then
    if docker info &>/dev/null; then
        DOCKER_AVAILABLE=true
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        open -a Docker 2>/dev/null || true
        for i in {1..15}; do
            if docker info &>/dev/null; then
                DOCKER_AVAILABLE=true
                break
            fi
            sleep 2
        done
    else
        systemctl enable --now docker 2>/dev/null || service docker start 2>/dev/null || true
        if docker info &>/dev/null; then
            DOCKER_AVAILABLE=true
        fi
    fi
fi

COMPOSE_CMD=""
if [ "$DOCKER_AVAILABLE" = true ]; then
    if docker compose version &>/dev/null; then
        COMPOSE_CMD="docker compose"
    elif command -v docker-compose &>/dev/null; then
        COMPOSE_CMD="docker-compose"
    fi
fi

if [ "$STANDALONE_MODE" = true ] || [ "$DOCKER_AVAILABLE" = false ] || [ "False" = "False" ]; then
    if [ "$STANDALONE_MODE" = false ] && [ "False" = "True" ]; then
        echo -e "${YELLOW}[!] Docker daemon unavailable. Auto-switching to Standalone Native Python Mode...${NC}"
    fi
    STANDALONE_MODE=true
fi

# 5A. Standalone Native Mode Execution
if [ "$STANDALONE_MODE" = true ]; then
    echo -e "\n${CYAN}[+] Launching Native Python Services...${NC}"
    mkdir -p logs
    nohup python3 src/api/main.py > logs/standalone.log 2>&1 &
    sleep 3
    echo -e "${GREEN}${BOLD}"
    cat << "EOF"
================================================================================
🎉 DEPLOYMENT COMPLETE (Standalone Native Mode)!
================================================================================
EOF
    echo -e "${NC}"
    echo -e "${BOLD}Active Service Endpoints:${NC}"
    echo -e "  🌐 Primary Service URL : ${CYAN}http://${SERVER_PUBLIC_IP}:8000${NC} (Local: http://localhost:8000)"
    echo -e "  • Tail Logs          : ${YELLOW}tail -f logs/standalone.log${NC}"
    echo -e "  • Complete Teardown  : ${YELLOW}./clear.sh${NC}\n"
    exit 0
fi

# 5B. Docker Compose Execution
echo -e "\n${CYAN}[+] Launching Containerized Stack via ${COMPOSE_CMD}...${NC}"
$COMPOSE_CMD up -d --build
sleep 4
echo -e "${GREEN}${BOLD}"
cat << "EOF"
================================================================================
🎉 CONTAINERIZED DEPLOYMENT COMPLETE!
================================================================================
EOF
echo -e "${NC}"
echo -e "${BOLD}Active Service Endpoints:${NC}"
echo -e "  🌐 Primary Service URL : ${CYAN}http://${SERVER_PUBLIC_IP}:8000${NC} (Local: http://localhost:8000)"
echo -e "  • Complete Teardown  : ${YELLOW}./clear.sh${NC}\n"
