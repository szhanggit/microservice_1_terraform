terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.39"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.38"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.16"
    }
  }
}

provider "aws" {
  region = var.region
}

data "aws_caller_identity" "current" {}

provider "kubernetes" {
  host                   = module.eks_cluster.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks_cluster.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["--region", var.region, "eks", "get-token", "--cluster-name", var.cluster_name]
  }
}

# Used only by modules/keda's helm_release - no other Helm charts in this
# project (everything else is installed via a separate app-deploy pipeline,
# matching how microservice_0 installs the ALB controller chart outside
# Terraform; KEDA is the exception since there's no such pipeline here yet).
provider "helm" {
  kubernetes {
    host                   = module.eks_cluster.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks_cluster.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["--region", var.region, "eks", "get-token", "--cluster-name", var.cluster_name]
    }
  }
}

locals {
  # cluster_name doubles as the namespace TransactionGateway/TransactionService/
  # TransactionWorker manifests deploy into, same convention microservice_0 uses.
  app_namespace = var.cluster_name

  # Per-environment resource names - every environment shares one AWS account,
  # so naming (not account separation) is what keeps them from colliding
  # (Terraform.md §6).
  queue_name          = "TransactionQueue-${var.environment}"
  dynamodb_table_name = "transaction-claims-${var.environment}"
}

module "vpc" {
  source = "./modules/vpc"

  cluster_name         = var.cluster_name
  vpc_cidr_block       = var.vpc_cidr_block
  azs                  = var.azs
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
}

module "eks_cluster" {
  source = "./modules/eks-cluster"

  cluster_name       = var.cluster_name
  kubernetes_version = var.kubernetes_version
  public_subnet_ids  = module.vpc.public_subnet_ids

  # GitHub Actions' OIDC role (created in the separate github-actions-oidc/
  # state) gets an EKS access entry here so its workflows can run kubectl/helm
  # against this cluster. Computed directly rather than via
  # var.additional_admin_role_arn's blank default, since that role lives in a
  # different Terraform state and can't be passed in as a module output.
  additional_admin_role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.github_actions_role_name}"

  depends_on = [module.vpc]
}

module "eks_nodegroup" {
  source = "./modules/eks-nodegroup"

  cluster_name        = var.cluster_name
  nodegroup_name      = var.nodegroup_name
  node_instance_type  = var.node_instance_type
  node_desired_size   = var.node_desired_size
  node_min_size       = var.node_min_size
  node_max_size       = var.node_max_size
  node_volume_size    = var.node_volume_size
  ssh_public_key_name = var.ssh_public_key_name
  subnet_ids          = module.vpc.private_subnet_ids

  depends_on = [module.eks_cluster]
}

module "eks_ebs_csi" {
  source = "./modules/eks-ebs-csi"

  cluster_name      = var.cluster_name
  oidc_provider_arn = module.eks_cluster.oidc_provider_arn
  oidc_provider_url = module.eks_cluster.oidc_provider_url

  depends_on = [module.eks_nodegroup]
}

module "eks_alb_controller" {
  source = "./modules/eks-alb-controller"

  cluster_name      = var.cluster_name
  oidc_provider_arn = module.eks_cluster.oidc_provider_arn
  oidc_provider_url = module.eks_cluster.oidc_provider_url

  depends_on = [module.eks_nodegroup]
}

module "eks_external_dns" {
  source = "./modules/eks-external-dns"

  cluster_name      = var.cluster_name
  oidc_provider_arn = module.eks_cluster.oidc_provider_arn
  oidc_provider_url = module.eks_cluster.oidc_provider_url

  depends_on = [module.eks_nodegroup]
}

module "eks_cluster_autoscaler" {
  source = "./modules/eks-cluster-autoscaler"

  cluster_name      = var.cluster_name
  oidc_provider_arn = module.eks_cluster.oidc_provider_arn
  oidc_provider_url = module.eks_cluster.oidc_provider_url

  depends_on = [module.eks_nodegroup]
}

# Per-environment repos (not shared across develop/staging/production) - each
# environment applies in its own separate Terraform state (Terraform.md §3),
# so a single shared repository name would collide across states on the 2nd
# and 3rd apply. Images are tagged per build regardless.
module "ecr" {
  source = "./modules/ecr"

  repository_names  = var.ecr_repository_names
  repository_prefix = var.cluster_name
}

module "keda" {
  source = "./modules/keda"

  depends_on = [module.eks_nodegroup]
}

resource "kubernetes_namespace" "app" {
  metadata {
    name = local.app_namespace
  }

  depends_on = [module.eks_nodegroup]
}

# --- Data layer: DB (4x, plain RDS PostgreSQL - see modules/rds-postgres-instance
# for why this isn't Aurora), DynamoDB, SQS, ElastiCache (2x) ---
# Schema/config for all of these comes straight from database.md, KEDA.md,
# SQS.md, TransactionGateway.md, and TransactionService.md - see Terraform.md
# §6 for the full mapping.

/* Dropped to fit the account's current RDS instance ceiling (only 2 concurrent
   creates succeeded on 2026-08-01 despite the account's Service Quota for "DB
   instances" showing 40 - looks like an AWS-side new-account/free-tier
   throttle, not a config problem). Re-enable once the account can take more.
module "db_shard_0" {
  source = "./modules/rds-postgres-instance"

  instance_identifier        = "${var.cluster_name}-shard-0"
  vpc_id                     = module.vpc.vpc_id
  vpc_cidr_block             = var.vpc_cidr_block
  private_subnet_ids         = module.vpc.private_subnet_ids
  master_username            = var.db_master_username
  master_password            = var.db_master_password
  instance_class              = var.db_instance_class
  enable_logical_replication  = true

  depends_on = [module.vpc]
}
*/

module "db_shard_1" {
  source = "./modules/rds-postgres-instance"

  instance_identifier            = "${var.cluster_name}-shard-1"
  vpc_id                         = module.vpc.vpc_id
  vpc_cidr_block                 = var.vpc_cidr_block
  # Temporary: public subnets (routed to the IGW) instead of private
  # (NAT-only, outbound-only) - publicly_accessible alone doesn't help if the
  # subnet itself has no inbound path from the internet. Security group
  # (locked to local_dev_ip_cidr's /32 + the VPC CIDR) is the real gate, not
  # subnet placement. Falls back to private subnets once local_dev_ip_cidr is
  # emptied out again - see variables.tf's note.
  private_subnet_ids             = length(var.local_dev_ip_cidr) > 0 ? module.vpc.public_subnet_ids : module.vpc.private_subnet_ids
  master_username                = var.db_master_username
  master_password                = var.db_master_password
  instance_class                  = var.db_instance_class
  enable_logical_replication      = true
  publicly_accessible             = length(var.local_dev_ip_cidr) > 0
  additional_ingress_cidr_blocks  = var.local_dev_ip_cidr

  depends_on = [module.vpc]
}

/* Dropped alongside shard_0 to fit the account's proven RDS instance ceiling
   (2 concurrent creates) - keeping shard_1 + reporting = 2 total. Re-enable
   once the account can take more.
module "db_shard_2" {
  source = "./modules/rds-postgres-instance"

  instance_identifier        = "${var.cluster_name}-shard-2"
  vpc_id                     = module.vpc.vpc_id
  vpc_cidr_block             = var.vpc_cidr_block
  private_subnet_ids         = module.vpc.private_subnet_ids
  master_username            = var.db_master_username
  master_password            = var.db_master_password
  instance_class              = var.db_instance_class
  enable_logical_replication  = true

  depends_on = [module.vpc]
}
*/

module "db_reporting" {
  source = "./modules/rds-postgres-instance"

  instance_identifier             = "${var.cluster_name}-reporting"
  vpc_id                          = module.vpc.vpc_id
  vpc_cidr_block                  = var.vpc_cidr_block
  # Temporary: public subnets - see db_shard_1's comment above for why.
  private_subnet_ids              = length(var.local_dev_ip_cidr) > 0 ? module.vpc.public_subnet_ids : module.vpc.private_subnet_ids
  master_username                 = var.db_master_username
  master_password                 = var.db_master_password
  instance_class                  = var.db_instance_class
  publicly_accessible             = length(var.local_dev_ip_cidr) > 0
  additional_ingress_cidr_blocks  = var.local_dev_ip_cidr

  depends_on = [module.vpc]
}

# The security group + subnet group for each shard/reporting DB were already
# created under the old module instance names (aurora_shard_0, etc.) before
# the Aurora-to-plain-RDS switch. These `moved` blocks let Terraform re-adopt
# them under the new names instead of destroying and recreating (which would
# otherwise risk an "already exists" collision, since create/destroy ordering
# across unrelated module addresses isn't guaranteed). The DB instance itself
# has no prior state to move - every aws_rds_cluster create attempt failed
# before the resource was ever actually created, so it's a clean "add".
/* shard_0 dropped for now - see the commented module "db_shard_0" above.
moved {
  from = module.aurora_shard_0.aws_security_group.this
  to   = module.db_shard_0.aws_security_group.this
}
moved {
  from = module.aurora_shard_0.aws_db_subnet_group.this
  to   = module.db_shard_0.aws_db_subnet_group.this
}
*/
moved {
  from = module.aurora_shard_1.aws_security_group.this
  to   = module.db_shard_1.aws_security_group.this
}
moved {
  from = module.aurora_shard_1.aws_db_subnet_group.this
  to   = module.db_shard_1.aws_db_subnet_group.this
}
/* shard_2 dropped for now - see the commented module "db_shard_2" above.
moved {
  from = module.aurora_shard_2.aws_security_group.this
  to   = module.db_shard_2.aws_security_group.this
}
moved {
  from = module.aurora_shard_2.aws_db_subnet_group.this
  to   = module.db_shard_2.aws_db_subnet_group.this
}
*/
moved {
  from = module.aurora_reporting.aws_security_group.this
  to   = module.db_reporting.aws_security_group.this
}
moved {
  from = module.aurora_reporting.aws_db_subnet_group.this
  to   = module.db_reporting.aws_db_subnet_group.this
}

# --- CDC pipeline (database.md §7, Terraform.md §3/§6) ---
# Feeds the reporting instance so TransactionService's SearchByDateRange has
# real data to query. Requires scripts/bootstrap-dms-roles.sh run once first.
# UNVALIDATED - written but not yet applied against real AWS.

module "dms" {
  source = "./modules/dms"

  replication_instance_id = "${var.cluster_name}-cdc"
  vpc_id                  = module.vpc.vpc_id
  vpc_cidr_block          = var.vpc_cidr_block
  private_subnet_ids      = module.vpc.private_subnet_ids

  target_server_name   = module.db_reporting.address
  target_port           = module.db_reporting.port
  target_database_name = module.db_reporting.database_name
  target_username       = var.db_master_username
  target_password       = var.db_master_password

  depends_on = [module.db_reporting]
}

/* shard_0 dropped for now - see the commented module "db_shard_0" above.
module "dms_source_task_shard_0" {
  source = "./modules/dms-source-endpoint-task"

  shard_id                 = 0
  replication_instance_arn = module.dms.replication_instance_arn
  target_endpoint_arn      = module.dms.target_endpoint_arn
  source_server_name       = module.db_shard_0.address
  source_port               = module.db_shard_0.port
  source_database_name     = module.db_shard_0.database_name
  source_username           = var.db_master_username
  source_password           = var.db_master_password

  depends_on = [module.dms, module.db_shard_0]
}
*/

module "dms_source_task_shard_1" {
  source = "./modules/dms-source-endpoint-task"

  shard_id                 = 1
  replication_instance_arn = module.dms.replication_instance_arn
  target_endpoint_arn      = module.dms.target_endpoint_arn
  source_server_name       = module.db_shard_1.address
  source_port               = module.db_shard_1.port
  source_database_name     = module.db_shard_1.database_name
  source_username           = var.db_master_username
  source_password           = var.db_master_password

  depends_on = [module.dms, module.db_shard_1]
}

/* shard_2 dropped for now - see the commented module "db_shard_2" above.
module "dms_source_task_shard_2" {
  source = "./modules/dms-source-endpoint-task"

  shard_id                 = 2
  replication_instance_arn = module.dms.replication_instance_arn
  target_endpoint_arn      = module.dms.target_endpoint_arn
  source_server_name       = module.db_shard_2.address
  source_port               = module.db_shard_2.port
  source_database_name     = module.db_shard_2.database_name
  source_username           = var.db_master_username
  source_password           = var.db_master_password

  depends_on = [module.dms, module.db_shard_2]
}
*/

module "dynamodb" {
  source = "./modules/dynamodb"

  table_name = local.dynamodb_table_name
}

module "sqs" {
  source = "./modules/sqs"

  queue_name = local.queue_name
}

module "elasticache_gateway" {
  source = "./modules/elasticache"

  cluster_id          = "${var.cluster_name}-gw-cache"
  vpc_id              = module.vpc.vpc_id
  vpc_cidr_block      = var.vpc_cidr_block
  private_subnet_ids  = module.vpc.private_subnet_ids

  depends_on = [module.vpc]
}

module "elasticache_service" {
  source = "./modules/elasticache"

  cluster_id          = "${var.cluster_name}-svc-cache"
  vpc_id              = module.vpc.vpc_id
  vpc_cidr_block      = var.vpc_cidr_block
  private_subnet_ids  = module.vpc.private_subnet_ids

  depends_on = [module.vpc]
}

# --- IRSA roles (Terraform.md §7) ---
# TransactionGateway gets no IRSA role - it only talks to Redis and gRPC,
# never an AWS API directly.

data "aws_iam_policy_document" "transaction_service_sqs" {
  statement {
    effect    = "Allow"
    actions   = ["sqs:SendMessage"]
    resources = [module.sqs.queue_arn]
  }
}

module "irsa_transaction_service" {
  source = "./modules/irsa-service-role"

  role_name             = "${var.cluster_name}-transaction-service-role"
  oidc_provider_arn     = module.eks_cluster.oidc_provider_arn
  oidc_provider_url     = module.eks_cluster.oidc_provider_url
  namespace             = local.app_namespace
  service_account_name  = "transaction-service"
  policy_json           = data.aws_iam_policy_document.transaction_service_sqs.json

  depends_on = [kubernetes_namespace.app]
}

data "aws_iam_policy_document" "transaction_worker" {
  statement {
    effect    = "Allow"
    actions   = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes"]
    resources = [module.sqs.queue_arn]
  }

  statement {
    effect  = "Allow"
    actions = ["dynamodb:PutItem", "dynamodb:UpdateItem", "dynamodb:Query"]
    resources = [
      module.dynamodb.table_arn,
      "${module.dynamodb.table_arn}/index/${module.dynamodb.gsi_name}",
    ]
  }
}

module "irsa_transaction_worker" {
  source = "./modules/irsa-service-role"

  role_name             = "${var.cluster_name}-transaction-worker-role"
  oidc_provider_arn     = module.eks_cluster.oidc_provider_arn
  oidc_provider_url     = module.eks_cluster.oidc_provider_url
  namespace             = local.app_namespace
  service_account_name  = "transaction-worker"
  policy_json           = data.aws_iam_policy_document.transaction_worker.json

  depends_on = [kubernetes_namespace.app]
}

# This is what the KEDA aws-sqs-queue scaler's TriggerAuthentication uses to
# read ApproximateNumberOfMessages (KEDA.md §6) - the service account lives in
# the app namespace alongside the ScaledObject it authenticates, not in the
# keda namespace where the KEDA operator itself runs.
data "aws_iam_policy_document" "keda_trigger_auth" {
  statement {
    effect    = "Allow"
    actions   = ["sqs:GetQueueAttributes"]
    resources = [module.sqs.queue_arn]
  }
}

module "irsa_keda_trigger_auth" {
  source = "./modules/irsa-service-role"

  role_name             = "${var.cluster_name}-keda-trigger-auth-role"
  oidc_provider_arn     = module.eks_cluster.oidc_provider_arn
  oidc_provider_url     = module.eks_cluster.oidc_provider_url
  namespace             = local.app_namespace
  service_account_name  = "keda-trigger-auth"
  policy_json           = data.aws_iam_policy_document.keda_trigger_auth.json

  depends_on = [kubernetes_namespace.app]
}
