output "external_dns_policy_arn" {
  value = aws_iam_policy.external_dns.arn
}

output "external_dns_role_arn" {
  value = aws_iam_role.external_dns.arn
}
