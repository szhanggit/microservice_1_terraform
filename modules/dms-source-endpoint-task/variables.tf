variable "shard_id" {
  description = "0, 1, or 2 (database.md §4) - stamped as a literal into every replicated row via the table-mapping transformation rule below."
  type        = number

  validation {
    condition     = var.shard_id >= 0 && var.shard_id <= 2
    error_message = "shard_id must be 0, 1, or 2 - database.md §4's fixed 3-shard routing."
  }
}

variable "replication_instance_arn" {
  type = string
}

variable "target_endpoint_arn" {
  description = "The shared reporting-instance target endpoint (module.dms.target_endpoint_arn)"
  type        = string
}

variable "source_server_name" {
  description = "This shard's RDS address (module.db_shard_N.address)"
  type        = string
}

variable "source_port" {
  type    = number
  default = 5432
}

variable "source_database_name" {
  type = string
}

variable "source_username" {
  type = string
}

variable "source_password" {
  type      = string
  sensitive = true
}

variable "source_table_schema" {
  description = "Postgres schema the transactions table lives in"
  type        = string
  default     = "public"
}
