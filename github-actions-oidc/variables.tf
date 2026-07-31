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
# can't be silently hijacked if this org/repo is later renamed. These are
# placeholders - the first real AssumeRoleWithWebIdentity call from a GitHub
# Actions workflow will fail AccessDenied against a name-only policy; find the
# real values afterwards via CloudTrail (`aws cloudtrail lookup-events
# --lookup-attributes AttributeKey=EventName,AttributeValue=AssumeRoleWithWebIdentity`)
# and update these two, then re-apply (Terraform.md §9).
variable "github_owner_id" {
  description = "Immutable numeric ID for the szhanggit account/org - placeholder, confirm via CloudTrail (see comment above)"
  type        = string
  default     = "17355395"
}

variable "github_repo_id" {
  description = "Immutable numeric ID for the microservice_1 repo - placeholder, confirm via CloudTrail (see comment above)"
  type        = string
  default     = "0"
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
