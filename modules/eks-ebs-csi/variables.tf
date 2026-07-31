variable "cluster_name" {
  description = "EKS cluster name the EBS CSI addon is installed into"
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN of the cluster's IAM OIDC provider, for IRSA trust policy"
  type        = string
}

variable "oidc_provider_url" {
  description = "URL of the cluster's IAM OIDC provider, for IRSA trust policy"
  type        = string
}
