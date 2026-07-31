variable "table_name" {
  description = "e.g. transaction-claims-develop"
  type        = string
}

variable "billing_mode" {
  description = "PAY_PER_REQUEST - no per-hour charge while idle, cheaper for a demo's intermittent traffic than provisioned capacity (KEDA.md §5)"
  type        = string
  default     = "PAY_PER_REQUEST"
}

variable "gsi_name" {
  type    = string
  default = "gsi_status_lease"
}
