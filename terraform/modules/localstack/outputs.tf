output "namespace" {
  description = "LocalStack namespace"
  value       = kubernetes_namespace.localstack.metadata[0].name
}

output "release_name" {
  description = "LocalStack Helm release name"
  value       = helm_release.localstack.name
}

output "service_url" {
  description = "LocalStack service URL"
  value       = "http://localhost:${var.node_port}"
}

output "health_check_url" {
  description = "LocalStack health check URL"
  value       = "http://localhost:${var.node_port}/_localstack/health"
}
