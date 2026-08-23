output "role_arn" {
  value = aws_iam_role.this.arn
}

output "service_account_name" {
  value = var.create_service_account ? kubernetes_service_account.this[0].metadata[0].name : null
}

output "namespace" {
  value = var.create_service_account ? kubernetes_service_account.this[0].metadata[0].namespace : null
}
