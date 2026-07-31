output "role_arn" {
  description = "Paste into the GitHub repo's AWS_GITHUB_ACTIONS_ROLE_ARN secret (Settings -> Secrets and variables -> Actions). Also computed independently in ../main.tf (different state - can't reference this output directly) to grant this role an EKS access entry per environment."
  value       = aws_iam_role.github_actions.arn
}
