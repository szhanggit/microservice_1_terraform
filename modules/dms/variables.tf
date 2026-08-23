variable "replication_instance_id" {
  description = "e.g. microservice1-develop-cdc"
  type        = string
}

variable "vpc_id" {
  type = string
}

variable "vpc_cidr_block" {
  description = "CIDR block allowed to reach the replication instance's own management traffic - scoped to the VPC, nothing wider"
  type        = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "replication_instance_class" {
  description = "Smallest usable DMS instance class for a demo (Terraform.md §3) - dms.t3.micro is no longer orderable (see `aws dms describe-orderable-replication-instances`), dms.t3.small is the current floor"
  type        = string
  default     = "dms.t3.small"
}

variable "allocated_storage" {
  type    = number
  default = 20
}

variable "multi_az" {
  type    = bool
  default = false
}

variable "publicly_accessible" {
  type    = bool
  default = false
}

# --- Target endpoint (the reporting instance - database.md §7) ---

variable "target_server_name" {
  description = "Reporting instance's address (module.db_reporting.address)"
  type        = string
}

variable "target_port" {
  type    = number
  default = 5432
}

variable "target_database_name" {
  type = string
}

variable "target_username" {
  type = string
}

variable "target_password" {
  type      = string
  sensitive = true
}
