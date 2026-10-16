#!/usr/bin/env bash
# Run the assistant on your laptop (uses your local AWS credentials for Bedrock).
set -euo pipefail
cd "$(dirname "$0")"
export AWS_REGION_NAME="${AWS_REGION:-$(aws configure get region || echo us-east-1)}"
export WORKSPACE="${WORKSPACE:-$PWD/workspace}"
.venv/bin/adk web --port 8000 .
