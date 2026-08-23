variable "region" {
  type    = string
  default = "ca-central-1"
}

variable "github_repo" {
  description = "GitHub repo allowed to assume this role, as <org>/<repo> - scopes the OIDC trust policy so only workflow runs from this exact repo can assume it"
  type        = string
  default     = "szhanggit/microservice_1"
}

# GitHub's OIDC token `sub` claim actually looks like
# "repo:OWNER@OWNER_ID/REPO@REPO_ID:ref:refs/heads/develop" - immutable
# numeric IDs are embedded alongside the names specifically so a trust policy
# can't be silently hijacked if this org/repo is later renamed.
#
# RESOLVED (2026-08-02): github_repo_id was still the placeholder "0" -
# confirmed via `gh api repos/szhanggit/microservice_1 --jq '.id'`
# (1316490731) after a real workflow run failed with credentials never even
# being loaded (a separate, prior bug - AWS_GITHUB_ACTIONS_ROLE_ARN was never
# set as a GitHub secret at all, fixed separately via `gh secret set`).
# github_owner_id was already correct (`gh api user --jq '.id'` = 17355395).
# The live IAM role's trust policy was also patched directly via
# `aws iam update-assume-role-policy` to match this value immediately,
# without waiting on the next `terraform apply` from this state.
variable "github_owner_id" {
  description = "Immutable numeric ID for the szhanggit account/org"
  type        = string
  default     = "17355395"
}

variable "github_repo_id" {
  description = "Immutable numeric ID for the microservice_1 repo (gh api repos/szhanggit/microservice_1 --jq '.id')"
  type        = string
  default     = "1316490731"
}

variable "role_name" {
  description = "IAM role name. Also referenced by ../variables.tf's github_actions_role_name (default must match) - ../main.tf computes this role's ARN directly (different Terraform state, so it can't reference this module's output) to pass as the eks_cluster module's additional_admin_role_arn"
  type        = string
  default     = "github-actions-microservice1"
}

variable "route53_zone_id" {
  description = "Hosted zone ID this role is allowed to manage (ekslab.xyz - same zone microservice_0 uses)"
  type        = string
  default     = "Z01003713LZ694SBOOR14"
}
