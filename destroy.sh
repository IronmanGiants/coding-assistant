#!/usr/bin/env bash
# Delete everything so nothing keeps billing.
set -euo pipefail
REGION="${AWS_REGION:-$(aws configure get region || echo us-east-1)}"
aws cloudformation delete-stack --stack-name coding-assistant --region "$REGION"
aws cloudformation wait stack-delete-complete --stack-name coding-assistant --region "$REGION"
aws ecr delete-repository --repository-name coding-assistant --force --region "$REGION" >/dev/null
echo "✅ All coding-assistant resources deleted"
