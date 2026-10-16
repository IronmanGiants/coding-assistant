#!/usr/bin/env bash
# Build the image, push it to ECR, and deploy to ECS Fargate. Prints the URL at the end.
set -euo pipefail
cd "$(dirname "$0")"

REGION="${AWS_REGION:-$(aws configure get region || echo us-east-1)}"
MODEL_ID="${MODEL_ID:-bedrock/us.anthropic.claude-haiku-4-5-20251001-v1:0}"
STACK=coding-assistant
REPO=coding-assistant
ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
REGISTRY="$ACCOUNT.dkr.ecr.$REGION.amazonaws.com"
TAG=$(date +%Y%m%d%H%M%S)
IMAGE="$REGISTRY/$REPO:$TAG"

echo "==> Account $ACCOUNT, region $REGION, model $MODEL_ID"

echo "==> Ensuring ECR repository"
aws ecr describe-repositories --repository-names "$REPO" --region "$REGION" >/dev/null 2>&1 \
  || aws ecr create-repository --repository-name "$REPO" --region "$REGION" >/dev/null

echo "==> Building and pushing image (linux/arm64)"
aws ecr get-login-password --region "$REGION" | docker login --username AWS --password-stdin "$REGISTRY"
docker build --platform linux/arm64 -t "$IMAGE" .
docker push "$IMAGE"

echo "==> Looking up default VPC and your public IP"
VPC=$(aws ec2 describe-vpcs --filters Name=isDefault,Values=true --query 'Vpcs[0].VpcId' --output text --region "$REGION")
SUBNETS=$(aws ec2 describe-subnets --filters Name=vpc-id,Values="$VPC" Name=default-for-az,Values=true \
  --query 'Subnets[].SubnetId' --output text --region "$REGION" | tr '\t' ',')
MYIP=$(curl -s https://checkip.amazonaws.com)

echo "==> Deploying CloudFormation stack (takes ~3-5 min the first time)"
aws cloudformation deploy --region "$REGION" --stack-name "$STACK" \
  --template-file infra/ecs.yaml --capabilities CAPABILITY_IAM \
  --parameter-overrides ImageUri="$IMAGE" ModelId="$MODEL_ID" VpcId="$VPC" \
    SubnetIds="$SUBNETS" AllowedCidr="$MYIP/32"

echo "==> Waiting for the task to be running"
aws ecs wait services-stable --cluster "$STACK" --services "$STACK" --region "$REGION"
TASK=$(aws ecs list-tasks --cluster "$STACK" --service-name "$STACK" --query 'taskArns[0]' --output text --region "$REGION")
ENI=$(aws ecs describe-tasks --cluster "$STACK" --tasks "$TASK" --region "$REGION" \
  --query "tasks[0].attachments[0].details[?name=='networkInterfaceId'].value" --output text)
IP=$(aws ec2 describe-network-interfaces --network-interface-ids "$ENI" --region "$REGION" \
  --query 'NetworkInterfaces[0].Association.PublicIp' --output text)

echo
echo "✅ Coding assistant is live: http://$IP:8000   (pick 'coding_agent' in the top-left)"
echo "   Only reachable from your IP ($MYIP). Logs: aws logs tail /ecs/coding-assistant --follow --region $REGION"
