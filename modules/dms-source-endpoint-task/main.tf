# One shard's DMS source endpoint + CDC-only replication task into the
# shared reporting target (database.md §7, Terraform.md §6). Applied 3x from
# the root (shard-0/1/2), same reusable-module pattern as rds-postgres-instance.
#
# UNVALIDATED (Terraform.md §3/§6): the table-mapping transformation below is
# a first draft against DMS's documented "add-column" capability, not
# something exercised against a real replication task yet. Expect to debug
# this against real DMS logs/errors before it actually replicates correctly.

resource "aws_dms_endpoint" "source" {
  endpoint_id   = "microservice1-shard-${var.shard_id}-source"
  endpoint_type = "source"
  engine_name   = "postgres"

  server_name   = var.source_server_name
  port          = var.source_port
  database_name = var.source_database_name
  username      = var.source_username
  password      = var.source_password

  tags = {
    Name = "microservice1-shard-${var.shard_id}-source"
  }
}

locals {
  # Renames the source `transactions` table to `transactions_reporting` on
  # write, and stamps every replicated row with this task's shard_id as a
  # literal-valued new column (database.md §7's transactions_reporting.shard_id
  # column) - since the source table has no such column to derive it from.
  # Hyphenated keys must be quoted - they aren't valid bare HCL identifiers,
  # even though they're required by DMS's JSON table-mapping schema.
  table_mappings = {
    rules = [
      {
        "rule-type" = "selection"
        "rule-id"   = "1"
        "rule-name" = "1"
        "object-locator" = {
          "schema-name" = var.source_table_schema
          "table-name"  = "transactions"
        }
        "rule-action" = "include"
      },
      {
        "rule-type"   = "transformation"
        "rule-id"     = "2"
        "rule-name"   = "2"
        "rule-target" = "table"
        "object-locator" = {
          "schema-name" = var.source_table_schema
          "table-name"  = "transactions"
        }
        "rule-action" = "rename"
        "value"       = "transactions_reporting"
      },
      {
        "rule-type"   = "transformation"
        "rule-id"     = "3"
        "rule-name"   = "3"
        "rule-target" = "column"
        "object-locator" = {
          "schema-name" = var.source_table_schema
          "table-name"  = "transactions"
        }
        "rule-action" = "add-column"
        "value"       = "shard_id"
        "expression"  = tostring(var.shard_id)
        "data-type" = {
          "type" = "int2"
        }
      },
    ]
  }
}

resource "aws_dms_replication_task" "this" {
  replication_task_id      = "microservice1-shard-${var.shard_id}-to-reporting"
  migration_type           = "cdc"
  replication_instance_arn = var.replication_instance_arn
  source_endpoint_arn      = aws_dms_endpoint.source.endpoint_arn
  target_endpoint_arn      = var.target_endpoint_arn

  table_mappings = jsonencode(local.table_mappings)

  tags = {
    Name = "microservice1-shard-${var.shard_id}-to-reporting"
  }
}
