# IAM role assumed by the EKS control plane
resource "aws_iam_role" "cluster" {
  name = "${var.cluster_name}-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "eks.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "cluster_policy" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# EKS control plane in the public subnets (matches the VPC's
# "kubernetes.io/role/elb" tagging so the ALB controller can place
# internet-facing load balancers there).
resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  role_arn = aws_iam_role.cluster.arn
  version  = var.kubernetes_version

  vpc_config {
    subnet_ids = var.public_subnet_ids
  }

  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }

  depends_on = [aws_iam_role_policy_attachment.cluster_policy]
}

# Optional extra principal (the GitHub Actions OIDC role, see
# ../../github-actions-oidc/) granted cluster-admin via an EKS access entry -
# computed directly in ../../main.tf from the separate github-actions-oidc
# state, since it can't be passed as a module output across states.
resource "aws_eks_access_entry" "additional_admin" {
  count = var.additional_admin_role_arn != "" ? 1 : 0

  cluster_name  = aws_eks_cluster.main.name
  principal_arn = var.additional_admin_role_arn
}

resource "aws_eks_access_policy_association" "additional_admin" {
  count = var.additional_admin_role_arn != "" ? 1 : 0

  cluster_name  = aws_eks_cluster.main.name
  principal_arn = aws_eks_access_entry.additional_admin[0].principal_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }
}

# Equivalent of:
# eksctl utils associate-iam-oidc-provider --approve
# Required for IRSA (IAM Roles for Service Accounts) used by every add-on
# module and by the per-service roles in modules/irsa-service-role.
data "tls_certificate" "eks" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]

  tags = {
    Name = "${var.cluster_name}-oidc"
  }
}

# Allow inbound NodePort traffic from the internet so NodePort-typed Services
# are reachable without an Ingress/ALB in front of them. The EKS-managed
# cluster security group only allows traffic from itself by default.
resource "aws_security_group_rule" "nodeport_ingress" {
  type              = "ingress"
  from_port         = 30000
  to_port           = 32767
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
  description       = "NodePort range for externally accessible NodePort services"
}
