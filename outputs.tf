output "region" {
  value = var.region
}

output "cluster_id" {
  value = module.eks_cluster.cluster_id
}

output "cluster_name" {
  value = module.eks_cluster.cluster_name
}

output "cluster_endpoint" {
  value = module.eks_cluster.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  value = module.eks_cluster.cluster_certificate_authority_data
}

output "cluster_security_group_id" {
  value = module.eks_cluster.cluster_security_group_id
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "public_subnet_ids" {
  value = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  value = module.vpc.private_subnet_ids
}

output "nat_gateway_id" {
  value = module.vpc.nat_gateway_id
}

output "oidc_provider_arn" {
  value = module.eks_cluster.oidc_provider_arn
}

output "oidc_provider_url" {
  value = module.eks_cluster.oidc_provider_url
}

output "nodegroup_arn" {
  value = module.eks_nodegroup.nodegroup_arn
}

output "nodegroup_status" {
  value = module.eks_nodegroup.nodegroup_status
}

output "node_role_arn" {
  value = module.eks_nodegroup.node_role_arn
}

output "ebs_csi_driver_role_arn" {
  value = module.eks_ebs_csi.ebs_csi_driver_role_arn
}

output "alb_controller_policy_arn" {
  value = module.eks_alb_controller.alb_controller_policy_arn
}

output "alb_controller_role_arn" {
  value = module.eks_alb_controller.alb_controller_role_arn
}

output "external_dns_policy_arn" {
  value = module.eks_external_dns.external_dns_policy_arn
}

output "external_dns_role_arn" {
  value = module.eks_external_dns.external_dns_role_arn
}

output "cluster_autoscaler_role_arn" {
  value = module.eks_cluster_autoscaler.cluster_autoscaler_role_arn
}

output "ecr_repository_urls" {
  description = "Map of service name -> ECR repository URL, e.g. { transactionworker = \"<acct>.dkr.ecr.ca-central-1.amazonaws.com/microservice1-develop/transactionworker\" }"
  value       = module.ecr.repository_urls
}

output "keda_namespace" {
  value = module.keda.namespace
}

output "db_shard_endpoints" {
  description = "Map of shard name -> RDS instance address (hostname only, no port)"
  value = {
    # shard-0 dropped for now - see the commented module "db_shard_0" in main.tf
    shard-1   = module.db_shard_1.address
    # shard-2 dropped for now - see the commented module "db_shard_2" in main.tf
    reporting = module.db_reporting.address
  }
}

output "dynamodb_table_name" {
  value = module.dynamodb.table_name
}

output "sqs_queue_url" {
  value = module.sqs.queue_url
}

output "sqs_queue_arn" {
  value = module.sqs.queue_arn
}

output "elasticache_gateway_endpoint" {
  value = module.elasticache_gateway.endpoint
}

output "elasticache_service_endpoint" {
  value = module.elasticache_service.endpoint
}

output "transaction_service_role_arn" {
  value = module.irsa_transaction_service.role_arn
}

output "transaction_worker_role_arn" {
  value = module.irsa_transaction_worker.role_arn
}

output "keda_trigger_auth_role_arn" {
  value = module.irsa_keda_trigger_auth.role_arn
}
