# Security group allowing inbound PostgreSQL access from inside the VPC only.
resource "aws_security_group" "this" {
  name        = "${var.instance_identifier}-sg"
  description = "Allow PostgreSQL access from within the VPC to ${var.instance_identifier}"
  vpc_id      = var.vpc_id

  ingress {
    description = "PostgreSQL from within the VPC"
    from_port   = var.port
    to_port     = var.port
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr_block]
  }

  tags = {
    Name = "${var.instance_identifier}-sg"
  }
}

resource "aws_db_subnet_group" "this" {
  name        = "${var.instance_identifier}-subnetgroup"
  description = "Subnet group for ${var.instance_identifier}"
  subnet_ids  = var.private_subnet_ids

  tags = {
    Name = "${var.instance_identifier}-subnetgroup"
  }
}

# Only created for DMS CDC source instances (database.md §7) - rds.logical_replication
# is a static parameter, so RDS requires it via a parameter group rather than a
# direct instance setting, and applying it forces a reboot to take effect.
resource "aws_db_parameter_group" "logical_replication" {
  count = var.enable_logical_replication ? 1 : 0

  name   = "${var.instance_identifier}-logical-replication"
  family = var.parameter_group_family

  parameter {
    name         = "rds.logical_replication"
    value        = "1"
    apply_method = "pending-reboot"
  }

  tags = {
    Name = "${var.instance_identifier}-logical-replication"
  }
}

# Plain RDS (not Aurora) - this account's Free Tier plan blocks Aurora cluster
# creation entirely: first the engine type (aurora-mysql rejected outright),
# then - after switching to aurora-postgresql - the cluster-creation mode
# itself (Free Tier requires "Express Configuration", which uses its own
# "Internet Access Gateway" networking and explicitly rejects a custom VPC
# subnet group/security group - confirmed via a direct `aws rds
# create-db-cluster --with-express-configuration` test). Plain RDS is the
# classic Free Tier offering and matches microservice_0's own `rds` module
# pattern (see Terraform.md). Loses Aurora Serverless v2 elasticity and the
# writer/reader Multi-AZ topology database.md originally called for - see
# database.md's engine/topology note for the full history.
resource "aws_db_instance" "this" {
  identifier     = var.instance_identifier
  engine         = "postgres"
  engine_version = var.engine_version

  db_name  = var.database_name
  username = var.master_username
  password = var.master_password
  port     = var.port

  instance_class    = var.instance_class
  allocated_storage = var.allocated_storage
  storage_type      = var.storage_type
  storage_encrypted = true

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.this.id]
  publicly_accessible    = var.publicly_accessible
  multi_az               = var.multi_az
  parameter_group_name   = var.enable_logical_replication ? aws_db_parameter_group.logical_replication[0].name : null

  backup_retention_period = var.backup_retention_period
  skip_final_snapshot     = var.skip_final_snapshot
}
