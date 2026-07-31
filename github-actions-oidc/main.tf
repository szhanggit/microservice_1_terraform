terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.39"
    }
  }
}

provider "aws" {
  region = var.region
}

data "aws_caller_identity" "current" {}

# GitHub's OIDC provider is a true account-wide singleton (one per unique URL
# per AWS account) - microservice_0's own github-actions-oidc/ already
# created it, and AWS rejects a second aws_iam_openid_connect_provider for the
# same URL (EntityAlreadyExists). Reference the existing one by its
# deterministic ARN instead of trying to manage it from this state too - two
# Terraform states owning the same account-wide resource is asking for a
# `destroy` in one to break the other.
locals {
  github_oidc_provider_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com"
}

data "aws_iam_policy_document" "github_actions_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.github_oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # StringLike (not StringEquals) - the trailing "*" is only a wildcard
    # under StringLike, scoping this to any branch/tag/workflow run in this
    # one repo. The owner/repo segments must include their immutable "@ID"
    # suffixes (see variables.tf's github_owner_id/github_repo_id) - a plain
    # "repo:${var.github_repo}:*" never matches the real token and silently
    # denies every assume-role call (confirmed via CloudTrail in
    # microservice_0; same fix applies here).
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "repo:${split("/", var.github_repo)[0]}@${var.github_owner_id}/${split("/", var.github_repo)[1]}@${var.github_repo_id}:*"
      ]
    }
  }
}

resource "aws_iam_role" "github_actions" {
  name               = var.role_name
  assume_role_policy = data.aws_iam_policy_document.github_actions_assume_role.json
}

# Scoped to exactly what CI needs - push images, describe the cluster to fetch
# a kubeconfig, and read the SSM/Secrets Manager values ../ssm-outputs.tf
# publishes. Actual kubectl-level access to the cluster comes from the EKS
# access entry modules/eks-cluster grants this role's ARN via
# additional_admin_role_arn (see ../main.tf), not from an IAM permission here.
data "aws_iam_policy_document" "github_actions_permissions" {
  statement {
    sid       = "EcrAuth"
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid    = "EcrPushPull"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:PutImage",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
    ]
    resources = ["arn:aws:ecr:*:${data.aws_caller_identity.current.account_id}:repository/microservice1-*/*"]
  }

  statement {
    sid       = "EksDescribe"
    effect    = "Allow"
    actions   = ["eks:DescribeCluster"]
    resources = ["arn:aws:eks:*:${data.aws_caller_identity.current.account_id}:cluster/microservice1-*"]
  }

  statement {
    sid       = "SsmRead"
    effect    = "Allow"
    actions   = ["ssm:GetParameter"]
    resources = ["arn:aws:ssm:*:${data.aws_caller_identity.current.account_id}:parameter/microservice1/*"]
  }

  statement {
    sid       = "SecretsManagerRead"
    effect    = "Allow"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = ["arn:aws:secretsmanager:*:${data.aws_caller_identity.current.account_id}:secret:microservice1/*"]
  }

  statement {
    sid       = "Route53ListZones"
    effect    = "Allow"
    actions   = ["route53:ListHostedZones", "route53:ListHostedZonesByName"]
    resources = ["*"] # Route53 list actions don't support resource-level scoping
  }

  statement {
    sid       = "Route53ManageEkslabZone"
    effect    = "Allow"
    actions   = ["route53:ListResourceRecordSets", "route53:ChangeResourceRecordSets"]
    resources = ["arn:aws:route53:::hostedzone/${var.route53_zone_id}"]
  }
}

resource "aws_iam_policy" "github_actions" {
  name   = "${var.role_name}-permissions"
  policy = data.aws_iam_policy_document.github_actions_permissions.json
}

resource "aws_iam_role_policy_attachment" "github_actions" {
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.github_actions.arn
}
