output "replication_instance_arn" {
  value = aws_dms_replication_instance.this.replication_instance_arn
}

output "target_endpoint_arn" {
  value = aws_dms_endpoint.reporting_target.endpoint_arn
}

output "security_group_id" {
  value = aws_security_group.this.id
}
