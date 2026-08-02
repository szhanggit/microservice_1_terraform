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

variable "operator_role_arn" {
  description = "IRSA role ARN to annotate the keda-operator ServiceAccount with (chart value serviceAccount.operator.annotations), so the aws-sqs-queue scaler can authenticate as the operator's own pod identity (TriggerAuthentication podIdentity.provider=aws with no identityOwner override, or identityOwner=keda). identityOwner=workload was tried first and confirmed NOT to work for scale-from-zero SQS polling even with a live target pod - see kubernetes/transaction-worker/triggerauthentication.yaml."
  type        = string
}
