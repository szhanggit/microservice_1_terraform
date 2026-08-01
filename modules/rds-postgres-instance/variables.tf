variable "instance_identifier" {
  description = "RDS instance identifier, e.g. microservice1-develop-shard-0"
  type        = string
}

variable "vpc_id" {
  type = string
}

variable "vpc_cidr_block" {
  description = "CIDR block allowed to reach PostgreSQL (5432) - scoped to the instance's own VPC, nothing wider"
  type        = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "database_name" {
  description = "Initial schema name created on the instance (the `transactions` table from database.md lives here)"
  type        = string
  default     = "transactions"
}

variable "master_username" {
  description = "\"admin\" is a reserved word for the RDS postgres engine (CreateDBInstance rejects it) - dbadmin matches microservice_0's own rds module default"
  type        = string
  default     = "dbadmin"
}

variable "master_password" {
  description = "Master password - set via secrets.tfvars, never committed"
  type        = string
  sensitive   = true
}

variable "port" {
  type    = number
  default = 5432
}

variable "engine_version" {
  description = "RDS PostgreSQL engine version - run `aws rds describe-db-engine-versions --engine postgres` to see what's currently offered in your region"
  type        = string
  default     = "18.4"
}

variable "instance_class" {
  description = "Free Tier eligible RDS instance class - matches microservice_0's own rds module default"
  type        = string
  default     = "db.t3.micro"
}

variable "allocated_storage" {
  type    = number
  default = 20
}

variable "storage_type" {
  type    = string
  default = "gp2"
}

variable "backup_retention_period" {
  description = "0 disables automated backups - fine for a demo environment that gets torn down and rebuilt, and avoids a destroy ever waiting behind a backup in progress"
  type        = number
  default     = 0
}

variable "skip_final_snapshot" {
  type    = bool
  default = true
}

variable "multi_az" {
  description = "false - this account's Free Tier plan is Single-AZ only; database.md's original Multi-AZ requirement is relaxed for this demo (see database.md's engine/topology note)"
  type        = bool
  default     = false
}

variable "publicly_accessible" {
  type    = bool
  default = false
}

variable "additional_ingress_cidr_blocks" {
  description = "Extra CIDR blocks (beyond vpc_cidr_block) allowed to reach 5432 - e.g. a developer's current public IP for local debugging against an otherwise VPC-private instance. Leave empty in normal operation."
  type        = list(string)
  default     = []
}

variable "enable_logical_replication" {
  description = "Set true only on DMS CDC source instances (the 3 shards, not the reporting target) - creates a custom parameter group with rds.logical_replication=1 and reboots the instance to apply it (database.md §7, Terraform.md §3). Written but not yet applied/validated - see Terraform.md §6."
  type        = bool
  default     = false
}

variable "parameter_group_family" {
  description = "Must match engine_version's major version (e.g. postgres18 for engine_version 18.4) - only used when enable_logical_replication is true."
  type        = string
  default     = "postgres18"
}
