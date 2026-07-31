variable "queue_name" {
  description = "e.g. TransactionQueue-develop"
  type        = string
}

variable "visibility_timeout_seconds" {
  description = "Short is fine - SQS's own timeout isn't the primary recovery path; TransactionWorker's DynamoDB claim/lease is (KEDA.md §5, SQS.md §2)"
  type        = number
  default     = 30
}

variable "message_retention_seconds" {
  default = 345600 # 4 days
  type    = number
}

variable "receive_wait_time_seconds" {
  description = "Long polling - reduces empty-receive API calls/cost"
  type        = number
  default     = 20
}

variable "max_receive_count" {
  description = "Receives before a message is routed to the DLQ"
  type        = number
  default     = 5
}

variable "dlq_message_retention_seconds" {
  default = 1209600 # 14 days - longer than the main queue since these need a human to look at them
  type    = number
}
