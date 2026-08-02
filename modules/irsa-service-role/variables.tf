variable "role_name" {
  type = string
}

variable "oidc_provider_arn" {
  description = "ARN of the cluster's IAM OIDC provider, for IRSA trust policy"
  type        = string
}

variable "oidc_provider_url" {
  description = "URL of the cluster's IAM OIDC provider, for IRSA trust policy"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace the service account lives in"
  type        = string
}

variable "service_account_name" {
  type = string
}

variable "policy_json" {
  description = "Fully-formed IAM policy document JSON (build it at the call site with a data \"aws_iam_policy_document\" block and pass its .json) - kept generic here so this one module covers TransactionService, TransactionWorker, and the KEDA TriggerAuthentication (Terraform.md §6/§7)"
  type        = string
}

variable "create_service_account" {
  description = "Whether this module creates the Kubernetes ServiceAccount itself. Set false when the ServiceAccount is already created elsewhere (e.g. by a Helm chart) and this module should only produce the IAM role/trust-policy pair - the caller is then responsible for annotating that ServiceAccount with the resulting role_arn output."
  type        = bool
  default     = true
}
