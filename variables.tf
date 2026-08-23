variable "cluster_name" {
  description = "EKS cluster name - also the Kubernetes namespace this project's manifests deploy into. Set per environment to microservice1-develop|staging|production."
  type        = string
  default     = "microservice1"
}

variable "environment" {
  description = "Environment name (develop/staging/production) - used as the SSM Parameter Store / Secrets Manager path prefix (see ssm-outputs.tf) and to suffix per-environment resource names (TransactionQueue-<env>, transaction-claims-<env>, etc.) so all three environments can coexist in one AWS account."
  type        = string
  default     = "develop"
}

variable "region" {
  description = "AWS region for everything in this project"
  type        = string
  default     = "ca-central-1"
}

variable "azs" {
  description = "Availability zones for the cluster's public/private subnets"
  type        = list(string)
  default     = ["ca-central-1a", "ca-central-1b"]
}

variable "kubernetes_version" {
  type    = string
  default = "1.31"
}

variable "additional_admin_role_arn" {
  description = "Optional extra IAM role ARN granted cluster-admin via an EKS access entry. Leave blank to skip."
  type        = string
  default     = ""
}

variable "github_actions_role_name" {
  description = "IAM role name for GitHub Actions OIDC, created in the separate github-actions-oidc/ state (an account-wide singleton, applied once - not per environment like everything else here). Referenced here only to compute its ARN for additional_admin_role_arn, since it's a different Terraform state so can't be passed as a module output - default must match github-actions-oidc/variables.tf's role_name."
  type        = string
  default     = "github-actions-microservice1"
}

variable "vpc_cidr_block" {
  type    = string
  default = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.0.0/24", "10.0.1.0/24"]
}

variable "private_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.2.0/24", "10.0.3.0/24"]
}

variable "nodegroup_name" {
  type    = string
  default = "microservice1-ng-private1"
}

variable "node_instance_type" {
  description = "t3.small - still Free Tier eligible for this account/region, but t3.micro's 3-pods-per-node ceiling (2 ENIs x 2 IPv4/ENI) left almost no room after the mandatory aws-node/kube-proxy daemonsets, so the EBS CSI addon (and everything after it) couldn't schedule at all. t3.small (3 ENIs x 4 IPv4/ENI = 8 pods/node) actually has headroom for the add-ons plus the 3 app services."
  type        = string
  default     = "t3.small"
}

variable "node_desired_size" {
  description = "4, not 2: at t3.small's 8-pods/node ceiling (5 schedulable slots after aws-node/kube-proxy/ebs-csi-node daemonsets), the ~10 baseline add-on pods (CoreDNS, EBS CSI controller, KEDA, ALB controller, external-dns, cluster-autoscaler) alone don't fit in 2 nodes - and cluster-autoscaler/ALB controller/external-dns are IRSA-only here (the actual pods come from a separate app-deploy pipeline), so nothing scales the node group past this floor until that pipeline is running."
  type        = number
  default     = 4
}

variable "node_min_size" {
  type    = number
  default = 1
}

variable "node_max_size" {
  description = "Sized for up to 5 replicas of TransactionWorker (KEDA-scaled) plus TransactionGateway/TransactionService plus cluster add-ons (~19 pods at peak, needing ~4 nodes at 5 schedulable slots/node) with headroom for rolling-update overlap"
  type        = number
  default     = 8
}

variable "node_volume_size" {
  type    = number
  default = 20
}

variable "ssh_public_key_name" {
  description = "Name of an existing EC2 key pair for SSH access to nodes. Leave blank to skip."
  type        = string
  default     = ""
}

variable "ecr_repository_names" {
  description = "Image names to create ECR repositories for - must match each service's Dockerfile image name"
  type        = list(string)
  default     = ["transactiongateway", "transactionservice", "transactionworker"]
}

# --- DB (modules/rds-postgres-instance, applied 4x: shard-0/1/2 + reporting) ---
# Plain RDS PostgreSQL, not Aurora - this account's Free Tier plan blocks
# Aurora cluster creation entirely (both the engine-type restriction and,
# after switching engines, the "Express Configuration" cluster-creation mode,
# which is incompatible with a VPC-private cluster). See
# modules/rds-postgres-instance/main.tf and database.md's engine/topology note.

variable "db_master_username" {
  description = "\"admin\" is a reserved word for the RDS postgres engine (CreateDBInstance rejects it) - dbadmin matches microservice_0's own rds module default"
  type        = string
  default     = "dbadmin"
}

variable "db_master_password" {
  description = "Master password for all 4 DB instances. Set in a local-only secrets.tfvars file, never commit it."
  type        = string
  sensitive   = true
}

variable "db_instance_class" {
  description = "Free Tier eligible RDS instance class - matches microservice_0's own rds module default. Single-AZ, single-instance only (no reader/replica) - Free Tier here doesn't support Multi-AZ."
  type        = string
  default     = "db.t3.micro"
}

variable "local_dev_ip_cidr" {
  description = "Temporary: developer's current public IP (as a /32 CIDR) allowed to reach the shard-1/reporting RDS instances directly for local debugging, since neither instance is reachable from outside the VPC otherwise (database.md/Terraform.md's local-dev-against-real-AWS approach doesn't cover VPC-private resources). Update this whenever your IP changes; revert to [] once local debugging no longer needs direct DB access. ElastiCache has no equivalent option - it cannot be made publicly accessible at all."
  type        = list(string)
  default     = []
}

# --- Read-only DB credentials for TransactionService's search path (new -
# TransactionService.md §2/§6) - a separate role from db_master_* above, so a
# bug in the search path can't write/delete data. Terraform only stores these
# in Secrets Manager (ssm-outputs.tf); it does not create the underlying
# Postgres role itself - that's the migration tooling's job (database.md §11
# Phase 2, not yet built - same pre-existing gap as the write-path schema).

variable "db_readonly_username" {
  type    = string
  default = "transactionservice_reader"
}

variable "db_readonly_password" {
  description = "Password for the read-only role, all 4 instances. Set in a local-only secrets.tfvars file, never commit it."
  type        = string
  sensitive   = true
}
