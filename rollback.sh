#!/bin/bash
set -e

TAG=$1
if [ -z "$TAG" ]; then
  echo "Uso: ./rollback.sh <commit-hash>"
  echo ""
  echo "Exemplo: ./rollback.sh 786a8c1"
  echo ""
  echo "Para ver versões disponíveis, execute: ./list-versions.sh"
  exit 1
fi

REGION="us-east-1"
CLUSTER="cluster-bia"
SERVICE="service-bia"
TASK_FAMILY="task-def-bia"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_URI="$ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/bia"

echo "=== Rollback para versão $TAG ==="
echo ""

echo "[1/3] Verificando se imagem existe..."
if ! aws ecr describe-images --repository-name bia --region $REGION --image-ids imageTag=$TAG > /dev/null 2>&1; then
  echo "❌ Erro: Imagem com tag '$TAG' não encontrada no ECR"
  exit 1
fi

echo "[2/3] Criando task definition com versão $TAG..."
TASK_DEF=$(aws ecs describe-task-definition --task-definition $TASK_FAMILY --region $REGION --query 'taskDefinition')
NEW_TASK_DEF=$(echo $TASK_DEF | jq --arg img "$ECR_URI:$TAG" '.containerDefinitions[0].image=$img | del(.taskDefinitionArn,.revision,.status,.requiresAttributes,.compatibilities,.registeredAt,.registeredBy)')
NEW_REVISION=$(echo $NEW_TASK_DEF | aws ecs register-task-definition --region $REGION --cli-input-json file:///dev/stdin --query 'taskDefinition.revision' --output text)

echo "Nova Task Definition: $TASK_FAMILY:$NEW_REVISION"

echo "[3/3] Atualizando serviço ECS..."
aws ecs update-service --region $REGION --cluster $CLUSTER --service $SERVICE --task-definition $TASK_FAMILY:$NEW_REVISION --query 'service.taskDefinition' --output text

echo ""
echo "✅ Rollback iniciado com sucesso!"
echo "Versão: $TAG"
echo "Task Definition: $TASK_FAMILY:$NEW_REVISION"
