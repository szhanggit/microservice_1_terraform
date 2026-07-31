output "namespace" {
  value = kubernetes_namespace.keda.metadata[0].name
}

output "release_status" {
  value = helm_release.keda.status
}
