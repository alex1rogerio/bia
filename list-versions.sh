#!/bin/bash

REGION="us-east-1"
ECR_REPO="bia"

echo "=== Versões disponíveis no ECR ==="
echo ""

aws ecr describe-images \
  --repository-name $ECR_REPO \
  --region $REGION \
  --query 'sort_by(imageDetails,&imagePushedAt)[*].[imageTags[0],imagePushedAt]' \
  --output table
