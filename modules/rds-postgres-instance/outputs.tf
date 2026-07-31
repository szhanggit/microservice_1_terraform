output "instance_identifier" {
  value = aws_db_instance.this.identifier
}

output "address" {
  description = "Hostname only (no port) - use with var.port to build a connection string"
  value       = aws_db_instance.this.address
}

output "port" {
  value = aws_db_instance.this.port
}

output "database_name" {
  value = aws_db_instance.this.db_name
}

output "security_group_id" {
  value = aws_security_group.this.id
}
