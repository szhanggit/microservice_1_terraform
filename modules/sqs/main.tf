# TransactionQueue-<env> (SQS.md): Standard (not FIFO), SSE-SQS encryption
# (free, vs. per-request-billed SSE-KMS). IAM for the 3 principals that touch
# this queue (TransactionService, TransactionWorker, KEDA TriggerAuthentication)
# is attached separately via modules/irsa-service-role at the root, keyed off
# this module's queue_arn/dlq_arn outputs.
resource "aws_sqs_queue" "dlq" {
  name                      = "${var.queue_name}-dlq"
  message_retention_seconds = var.dlq_message_retention_seconds
  sqs_managed_sse_enabled   = true

  tags = {
    Name = "${var.queue_name}-dlq"
  }
}

resource "aws_sqs_queue" "main" {
  name                       = var.queue_name
  visibility_timeout_seconds = var.visibility_timeout_seconds
  message_retention_seconds  = var.message_retention_seconds
  receive_wait_time_seconds  = var.receive_wait_time_seconds
  sqs_managed_sse_enabled    = true

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount      = var.max_receive_count
  })

  tags = {
    Name = var.queue_name
  }
}
