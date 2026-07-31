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
  type    = number
  default = 2
}

variable "node_min_size" {
  type    = number
  default = 1
}

variable "node_max_size" {
  description = "Sized for up to 5 replicas of TransactionWorker (KEDA-scaled) plus TransactionGateway/TransactionService plus cluster add-ons"
  type        = number
  default     = 4
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
