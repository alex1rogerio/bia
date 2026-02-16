#!/bin/bash
set -e

REGION="us-east-1"
ECR_REPO="bia"
CLUSTER="cluster-bia"
SERVICE="service-bia"
TASK_FAMILY="task-def-bia"

COMMIT_HASH=$(git rev-parse --short=7 HEAD)
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_URI="$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$ECR_REPO"

echo "=== Deploy com Versionamento ==="
echo "Commit: $COMMIT_HASH"
echo "ECR: $ECR_URI:$COMMIT_HASH"
echo ""

echo "[1/5] Login no ECR..."
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com

echo "[2/5] Build da imagem..."
docker build -t $ECR_URI:$COMMIT_HASH -t $ECR_URI:latest .

echo "[3/5] Push para ECR..."
docker push $ECR_URI:$COMMIT_HASH
docker push $ECR_URI:latest

echo "[4/5] Criando nova task definition..."
TASK_DEF=$(aws ecs describe-task-definition --task-definition $TASK_FAMILY --region $REGION)
echo $TASK_DEF | jq --arg img "$ECR_URI:$COMMIT_HASH" '.taskDefinition | .containerDefinitions[0].image=$img | {family,taskRoleArn,executionRoleArn,networkMode,containerDefinitions,volumes,placementConstraints,requiresCompatibilities,cpu,memory} | del(..|nulls)' > /tmp/new-task-def.json
NEW_REVISION=$(aws ecs register-task-definition --region $REGION --cli-input-json file:///tmp/new-task-def.json --query 'taskDefinition.revision' --output text)

echo "Nova Task Definition: $TASK_FAMILY:$NEW_REVISION"

echo "[5/5] Atualizando serviço ECS..."
aws ecs update-service --region $REGION --cluster $CLUSTER --service $SERVICE --task-definition $TASK_FAMILY:$NEW_REVISION --query 'service.taskDefinition' --output text

echo ""
echo "✅ Deploy iniciado com sucesso!"
echo "Versão: $COMMIT_HASH"
echo "Task Definition: $TASK_FAMILY:$NEW_REVISION"
