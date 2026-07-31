output "nodegroup_arn" {
  value = aws_eks_node_group.private1.arn
}

output "nodegroup_status" {
  value = aws_eks_node_group.private1.status
}

output "node_role_arn" {
  value = aws_iam_role.nodegroup.arn
}
