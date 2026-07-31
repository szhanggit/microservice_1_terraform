output "repository_urls" {
  description = "Map of service name -> full ECR repository URL (registry/repo, no tag)"
  value       = { for name, repo in aws_ecr_repository.app : name => repo.repository_url }
}

output "repository_arns" {
  value = { for name, repo in aws_ecr_repository.app : name => repo.arn }
}
