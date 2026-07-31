# transaction-claims table (KEDA.md §5): the claim-check/lease store
# TransactionWorker uses so DynamoDB - not SQS's own visibility timeout -
# is what actually recovers a message if a worker dies mid-processing.
resource "aws_dynamodb_table" "this" {
  name         = var.table_name
  billing_mode = var.billing_mode
  hash_key     = "transaction_no"

  attribute {
    name = "transaction_no"
    type = "S"
  }

  # Only attributes used as a key (table hash key or a GSI key) need to be
  # declared here - payload/worker_id/attempt_count are plain, undeclared
  # attributes written at item-put time.
  attribute {
    name = "status"
    type = "S"
  }

  attribute {
    name = "lease_expiry"
    type = "N"
  }

  # Supports the stale-claim scan: status = CLAIMED AND lease_expiry < now.
  global_secondary_index {
    name            = var.gsi_name
    hash_key        = "status"
    range_key       = "lease_expiry"
    projection_type = "ALL"
  }

  # Expires COMPLETED items a few minutes after completion (set by the app on
  # write, not here) so the table stays visibly clean in a demo.
  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  tags = {
    Name = var.table_name
  }
}
