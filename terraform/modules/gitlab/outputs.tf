output "namespace" {
  description = "GitLab namespace"
  value       = kubernetes_namespace.gitlab.metadata[0].name
}

output "release_name" {
  description = "GitLab Helm release name"
  value       = helm_release.gitlab.name
}

output "web_url" {
  description = "GitLab web UI URL"
  value       = "http://localhost:${var.web_node_port}"
}

output "ssh_url" {
  description = "GitLab SSH URL"
  value       = "ssh://git@localhost:${var.ssh_node_port}"
}

output "registry_url" {
  description = "GitLab registry URL"
  value       = "localhost:${var.registry_node_port}"
}

output "root_password_command" {
  description = "Command to retrieve GitLab root password"
  value       = "kubectl get secret ${var.release_name}-gitlab-initial-root-password -n ${var.namespace} -o jsonpath='{.data.password}' | base64 -d"
}
