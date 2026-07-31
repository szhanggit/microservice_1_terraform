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
