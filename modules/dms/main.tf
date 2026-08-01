# Shared CDC pipeline pieces (database.md §7, Terraform.md §3): the
# replication instance, its subnet/security groups, and the one target
# endpoint (the reporting instance) - each shard's own source endpoint + task
# lives in modules/dms-source-endpoint-task, applied 3x from the root.
#
# Requires scripts/bootstrap-dms-roles.sh to have been run once first - AWS
# DMS looks for dms-vpc-role/dms-cloudwatch-logs-role by their fixed,
# well-known names automatically; there is no ARN to pass in here, and
# replication-instance creation fails outright if those roles don't exist yet.
#
# UNVALIDATED: written but not yet applied against real AWS (Terraform.md §3).

resource "aws_security_group" "this" {
  name        = "${var.replication_instance_id}-sg"
  description = "DMS replication instance for ${var.replication_instance_id}"
  vpc_id      = var.vpc_id

  # DMS only needs outbound access to reach the source/target Postgres
  # instances (and AWS APIs) - nothing inbound is required.
  egress {
    description = "Postgres to shards/reporting instance"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr_block]
  }

  egress {
    description = "HTTPS to AWS APIs"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.replication_instance_id}-sg"
  }
}

resource "aws_dms_replication_subnet_group" "this" {
  replication_subnet_group_id          = "${var.replication_instance_id}-subnetgroup"
  replication_subnet_group_description = "Subnet group for ${var.replication_instance_id}"
  subnet_ids                           = var.private_subnet_ids
}

resource "aws_dms_replication_instance" "this" {
  replication_instance_id    = var.replication_instance_id
  replication_instance_class = var.replication_instance_class
  allocated_storage           = var.allocated_storage
  multi_az                    = var.multi_az
  publicly_accessible         = var.publicly_accessible

  replication_subnet_group_id = aws_dms_replication_subnet_group.this.id
  vpc_security_group_ids      = [aws_security_group.this.id]

  tags = {
    Name = var.replication_instance_id
  }
}

resource "aws_dms_endpoint" "reporting_target" {
  endpoint_id   = "${var.replication_instance_id}-target-reporting"
  endpoint_type = "target"
  engine_name   = "postgres"

  server_name   = var.target_server_name
  port          = var.target_port
  database_name = var.target_database_name
  username      = var.target_username
  password      = var.target_password

  tags = {
    Name = "${var.replication_instance_id}-target-reporting"
  }
}
