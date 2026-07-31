#!/usr/bin/env bash
# One-time setup for the remote state backend declared in ../backend.tf.
# Shared by all three environments (develop/staging/production) - each one's
# environments/<env>/backend.tfvars only overrides `key`, so they all live
# under the same bucket, just different state paths (same convention as
# microservice_0's terraform/scripts/bootstrap-backend.sh, and in fact the
# same bucket - "steven-zhang-learning" already exists from that project).
# Safe to re-run: every step is idempotent (checks before creating).
set -euo pipefail

BUCKET="steven-zhang-learning"
REGION="${AWS_REGION:-ca-central-1}"

if aws s3api head-bucket --bucket "$BUCKET" 2>/dev/null; then
  echo "S3 bucket '$BUCKET' already exists."
else
  echo "Creating S3 bucket '$BUCKET' in $REGION..."
  if [ "$REGION" = "us-east-1" ]; then
    aws s3api create-bucket --bucket "$BUCKET" --region "$REGION"
  else
    aws s3api create-bucket --bucket "$BUCKET" --region "$REGION" \
      --create-bucket-configuration LocationConstraint="$REGION"
  fi
fi

echo "Enabling versioning (state history / recovery)..."
aws s3api put-bucket-versioning --bucket "$BUCKET" \
  --versioning-configuration Status=Enabled

echo "Enabling default encryption (AES256)..."
aws s3api put-bucket-encryption --bucket "$BUCKET" \
  --server-side-encryption-configuration \
  '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'

echo "Blocking public access..."
aws s3api put-public-access-block --bucket "$BUCKET" \
  --public-access-block-configuration \
  BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

echo "Done. State will live at s3://$BUCKET/microservice1_dev|_stage|_prod/terraform.tfstate"

# --- Only needed on Terraform < 1.10, where backend.tf's use_lockfile isn't
# available and you need a DynamoDB table for state locking instead. Uncomment,
# add dynamodb_table = "microservice1-tf-lock" to each environment's
# backend.tfvars, and remove use_lockfile from ../backend.tf if so.
#
# aws dynamodb create-table \
#   --table-name microservice1-tf-lock \
#   --attribute-definitions AttributeName=LockID,AttributeType=S \
#   --key-schema AttributeName=LockID,KeyType=HASH \
#   --billing-mode PAY_PER_REQUEST \
#   --region "$REGION"
