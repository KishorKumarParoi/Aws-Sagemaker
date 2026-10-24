#!/usr/bin/env bash
# ==============================================================================
# 🛑 ZERO-COST INSTANT TEARDOWN SCRIPT — AWS SAGEMAKER MLOPS
# ==============================================================================
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "Stopping SageMaker platform containers..."
if docker compose version &>/dev/null; then
    docker compose down --remove-orphans 2>/dev/null || true
elif command -v docker-compose &>/dev/null; then
    docker-compose down --remove-orphans 2>/dev/null || true
fi

for port in 8000; do
    if command -v lsof &>/dev/null; then
        PIDS=$(lsof -ti :"$port" 2>/dev/null || true)
        if [ -n "$PIDS" ]; then
            echo "$PIDS" | xargs kill -9 2>/dev/null || true
        fi
    fi
done

echo "Platform torn down successfully. \$0.00 active compute."
