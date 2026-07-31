# Single-node Redis (no replication) - cheapest option for a demo idempotency
# cache (TransactionGateway.md §2/§6, TransactionService.md §2/§6). Applied
# twice at the root: once for the Gateway, once for TransactionService -
# deliberately separate instances, since each guards a different retry
# boundary (HTTP vs. gRPC).
resource "aws_security_group" "this" {
  name        = "${var.cluster_id}-sg"
  description = "Allow Redis access from within the VPC to ${var.cluster_id}"
  vpc_id      = var.vpc_id

  ingress {
    description = "Redis from within the VPC"
    from_port   = var.port
    to_port     = var.port
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr_block]
  }

  tags = {
    Name = "${var.cluster_id}-sg"
  }
}

resource "aws_elasticache_subnet_group" "this" {
  name       = "${var.cluster_id}-subnetgroup"
  subnet_ids = var.private_subnet_ids
}

resource "aws_elasticache_cluster" "this" {
  cluster_id           = var.cluster_id
  engine               = "redis"
  engine_version       = var.engine_version
  node_type            = var.node_type
  num_cache_nodes      = 1
  port                 = var.port
  subnet_group_name    = aws_elasticache_subnet_group.this.name
  security_group_ids   = [aws_security_group.this.id]

  tags = {
    Name = var.cluster_id
  }
}
