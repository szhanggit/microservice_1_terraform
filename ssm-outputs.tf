# Cross-pipeline handoff: writes the values a separate application/Kubernetes
# CI pipeline needs to SSM Parameter Store / Secrets Manager, mirroring
# microservice_0's ssm-outputs.tf (Terraform.md §10). That pipeline reads
# these via plain AWS CLI/SDK calls, with zero dependency on the Terraform
# CLI, this project's state, or S3 backend credentials.

locals {
  ssm_prefix = "/microservice1/${var.environment}"
}

resource "aws_ssm_parameter" "cluster_name" {
  name  = "${local.ssm_prefix}/cluster_name"
  type  = "String"
  value = module.eks_cluster.cluster_name
}

resource "aws_ssm_parameter" "region" {
  name  = "${local.ssm_prefix}/region"
  type  = "String"
  value = var.region
}

resource "aws_ssm_parameter" "vpc_id" {
  name  = "${local.ssm_prefix}/vpc_id"
  type  = "String"
  value = module.vpc.vpc_id
}

resource "aws_ssm_parameter" "ecr_repository_urls" {
  name  = "${local.ssm_prefix}/ecr_repository_urls"
  type  = "String"
  value = jsonencode(module.ecr.repository_urls)
}

resource "aws_ssm_parameter" "sqs_queue_url" {
  name  = "${local.ssm_prefix}/sqs_queue_url"
  type  = "String"
  value = module.sqs.queue_url
}

resource "aws_ssm_parameter" "sqs_queue_arn" {
  name  = "${local.ssm_prefix}/sqs_queue_arn"
  type  = "String"
  value = module.sqs.queue_arn
}

resource "aws_ssm_parameter" "dynamodb_table_name" {
  name  = "${local.ssm_prefix}/dynamodb_table_name"
  type  = "String"
  value = module.dynamodb.table_name
}

resource "aws_ssm_parameter" "elasticache_gateway_endpoint" {
  name  = "${local.ssm_prefix}/elasticache_gateway_endpoint"
  type  = "String"
  value = module.elasticache_gateway.endpoint
}

resource "aws_ssm_parameter" "elasticache_service_endpoint" {
  name  = "${local.ssm_prefix}/elasticache_service_endpoint"
  type  = "String"
  value = module.elasticache_service.endpoint
}

# Non-secret hostnames only - see the Secrets Manager entries below for the
# full connection strings (which carry the master password).
resource "aws_ssm_parameter" "db_shard_endpoints" {
  name = "${local.ssm_prefix}/db_shard_endpoints"
  type = "String"
  value = jsonencode({
    shard-0   = module.db_shard_0.address
    shard-1   = module.db_shard_1.address
    shard-2   = module.db_shard_2.address
    reporting = module.db_reporting.address
  })
}

resource "aws_ssm_parameter" "transaction_service_role_arn" {
  name  = "${local.ssm_prefix}/transaction_service_role_arn"
  type  = "String"
  value = module.irsa_transaction_service.role_arn
}

resource "aws_ssm_parameter" "transaction_worker_role_arn" {
  name  = "${local.ssm_prefix}/transaction_worker_role_arn"
  type  = "String"
  value = module.irsa_transaction_worker.role_arn
}

resource "aws_ssm_parameter" "keda_trigger_auth_role_arn" {
  name  = "${local.ssm_prefix}/keda_trigger_auth_role_arn"
  type  = "String"
  value = module.irsa_keda_trigger_auth.role_arn
}

# DB master connection strings - Secrets Manager (not plain SSM) since these
# hold the master password, one secret per instance (database.md §11 Phase 1,
# Terraform.md §10).
resource "aws_secretsmanager_secret" "db_connection_string" {
  for_each = {
    shard-0   = module.db_shard_0
    shard-1   = module.db_shard_1
    shard-2   = module.db_shard_2
    reporting = module.db_reporting
  }

  name = "microservice1/${var.environment}/db-${each.key}-connection-string"

  # Allows immediate deletion on `terraform destroy` instead of Secrets
  # Manager's default 7-30 day recovery window - this is a demo environment
  # that gets torn down and rebuilt, not something needing PITR.
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "db_connection_string" {
  for_each = {
    shard-0   = module.db_shard_0
    shard-1   = module.db_shard_1
    shard-2   = module.db_shard_2
    reporting = module.db_reporting
  }

  secret_id     = aws_secretsmanager_secret.db_connection_string[each.key].id
  secret_string = "Server=${each.value.address};Port=${each.value.port};Database=${each.value.database_name};User=${var.db_master_username};Password=${var.db_master_password};"
}

# Read-only DB connection strings for TransactionService's search path (new -
# TransactionService.md §2/§6) - separate secrets from the master ones above,
# since it's a different (read-only) Postgres role. The role itself isn't
# created by Terraform - see variables.tf's db_readonly_username/password.
resource "aws_secretsmanager_secret" "db_readonly_connection_string" {
  for_each = {
    shard-0   = module.db_shard_0
    shard-1   = module.db_shard_1
    shard-2   = module.db_shard_2
    reporting = module.db_reporting
  }

  name                    = "microservice1/${var.environment}/db-${each.key}-readonly-connection-string"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "db_readonly_connection_string" {
  for_each = {
    shard-0   = module.db_shard_0
    shard-1   = module.db_shard_1
    shard-2   = module.db_shard_2
    reporting = module.db_reporting
  }

  secret_id     = aws_secretsmanager_secret.db_readonly_connection_string[each.key].id
  secret_string = "Server=${each.value.address};Port=${each.value.port};Database=${each.value.database_name};User=${var.db_readonly_username};Password=${var.db_readonly_password};"
}
