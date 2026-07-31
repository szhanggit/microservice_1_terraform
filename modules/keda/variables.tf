variable "namespace" {
  description = "Namespace KEDA's own operator/metrics-server components run in - distinct from the app namespace where ScaledObject/TriggerAuthentication resources for TransactionWorker actually live"
  type        = string
  default     = "keda"
}

variable "chart_version" {
  description = "KEDA Helm chart version - check https://kedacore.github.io/charts for the current release before applying"
  type        = string
  default     = "2.16.1"
}
