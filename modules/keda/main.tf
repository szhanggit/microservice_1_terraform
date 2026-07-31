# No equivalent in the microservice_0 reference project (it scales via plain
# Kubernetes HPA) - installed here via the `helm` provider rather than a
# separate install script, since this project has no sibling "kubernetes"
# deploy pipeline (unlike the reference's ALB controller, which is installed
# that way).
resource "kubernetes_namespace" "keda" {
  metadata {
    name = var.namespace
  }
}

resource "helm_release" "keda" {
  name       = "keda"
  repository = "https://kedacore.github.io/charts"
  chart      = "keda"
  version    = var.chart_version
  namespace  = kubernetes_namespace.keda.metadata[0].name

  depends_on = [kubernetes_namespace.keda]
}
