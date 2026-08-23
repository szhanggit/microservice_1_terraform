#!/usr/bin/env bash
# One-time setup for AWS DMS's fixed-name, account-wide prerequisite IAM
# roles: dms-vpc-role and dms-cloudwatch-logs-role. AWS DMS looks for these
# by exact name automatically - there's no ARN to configure - and rejects
# replication-instance creation outright if they don't already exist.
#
# Not managed by the per-environment `dms` Terraform module (Terraform.md §3):
# these are account-wide singletons, so managing them inside a module applied
# separately per environment (develop/staging/production) would make the 2nd
# environment's apply fail with "role already exists" - same class of problem
# github-actions-oidc/ solves with a separate Terraform state; resolved here
# with a plain idempotent script instead, since these 2 roles never change.
#
# Safe to re-run: every step checks before creating.
#
# UNVALIDATED (Terraform.md §3): written but not yet run against a real AWS
# account - the managed policy ARNs below are AWS's documented ones for these
# roles, but haven't been exercised end-to-end with a real DMS replication
# instance yet.
set -euo pipefail

create_role_if_missing() {
  local role_name="$1"
  local trust_policy="$2"
  local managed_policy_arn="$3"

  if aws iam get-role --role-name "$role_name" >/dev/null 2>&1; then
    echo "IAM role '$role_name' already exists."
  else
    echo "Creating IAM role '$role_name'..."
    aws iam create-role --role-name "$role_name" \
      --assume-role-policy-document "$trust_policy" >/dev/null
  fi

  echo "Ensuring '$role_name' has $managed_policy_arn attached..."
  aws iam attach-role-policy --role-name "$role_name" --policy-arn "$managed_policy_arn"
}

DMS_TRUST_POLICY='{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": { "Service": "dms.amazonaws.com" },
      "Action": "sts:AssumeRole"
    }
  ]
}'

create_role_if_missing "dms-vpc-role" "$DMS_TRUST_POLICY" \
  "arn:aws:iam::aws:policy/service-role/AmazonDMSVPCManagementRole"

create_role_if_missing "dms-cloudwatch-logs-role" "$DMS_TRUST_POLICY" \
  "arn:aws:iam::aws:policy/service-role/AmazonDMSCloudWatchLogsRole"

echo "Done. Run this once per AWS account before applying the dms module."
