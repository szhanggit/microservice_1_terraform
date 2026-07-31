variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version for the EKS control plane"
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet IDs for the EKS control plane's VPC config"
  type        = list(string)
}

variable "additional_admin_role_arn" {
  description = <<-EOT
    Optional IAM role ARN to grant cluster-admin access via an EKS access entry,
    in addition to the Terraform caller (who already gets admin via
    bootstrap_cluster_creator_admin_permissions) - the GitHub Actions OIDC role
    from ../../github-actions-oidc/. Leave blank to skip.
  EOT
  type        = string
  default     = ""
}
