# IRSA equivalent of:
# eksctl create iamserviceaccount --cluster=<cluster> --namespace=kube-system
#   --name=cluster-autoscaler --attach-policy-arn=<cluster-autoscaler policy>
#   --override-existing-serviceaccounts --approve
#
# Bypasses IMDS entirely (unlike relying on the node's instance role), since
# EKS-managed node groups default to HttpPutResponseHopLimit=1, which blocks
# pods from reaching IMDS to assume the node role.
data "aws_iam_policy_document" "cluster_autoscaler_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(var.oidc_provider_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:cluster-autoscaler"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(var.oidc_provider_url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "cluster_autoscaler" {
  name               = "${var.cluster_name}-cluster-autoscaler-role"
  assume_role_policy = data.aws_iam_policy_document.cluster_autoscaler_assume_role.json
}

resource "aws_iam_role_policy" "cluster_autoscaler" {
  name = "PolicyClusterAutoscaler"
  role = aws_iam_role.cluster_autoscaler.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Resource = "*"
        Action = [
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:DescribeAutoScalingInstances",
          "autoscaling:DescribeLaunchConfigurations",
          "autoscaling:DescribeScalingActivities",
          "autoscaling:DescribeTags",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeLaunchTemplateVersions",
        ]
      },
      {
        Effect   = "Allow"
        Resource = "*"
        Action = [
          "autoscaling:SetDesiredCapacity",
          "autoscaling:TerminateInstanceInAutoScalingGroup",
          "ec2:DescribeImages",
          "ec2:GetInstanceTypesFromInstanceRequirements",
          "eks:DescribeNodegroup",
        ]
      },
    ]
  })
}

resource "kubernetes_service_account" "cluster_autoscaler" {
  metadata {
    name      = "cluster-autoscaler"
    namespace = "kube-system"

    labels = {
      "k8s-addon" = "cluster-autoscaler.addons.k8s.io"
      "k8s-app"   = "cluster-autoscaler"
    }

    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.cluster_autoscaler.arn
    }
  }
}
