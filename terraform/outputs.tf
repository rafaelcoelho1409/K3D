# K3D Cluster Outputs
output "cluster_name" {
  description = "Name of the K3D cluster"
  value       = module.k3d_cluster.cluster_name
}

output "cluster_context" {
  description = "Kubectl context for the cluster"
  value       = module.k3d_cluster.kubeconfig_context
}

output "registry_endpoint" {
  description = "Endpoint for the K3D registry"
  value       = module.k3d_cluster.registry_endpoint
}

# ArgoCD Outputs
output "argocd_url" {
  description = "ArgoCD web UI URL"
  value       = var.install_argocd ? "http://localhost:${var.argocd_host_port}" : "Not installed"
}

output "argocd_admin_password_command" {
  description = "Command to retrieve ArgoCD admin password"
  value       = var.install_argocd ? module.argocd[0].admin_password_command : "Not installed"
}

# GitLab Outputs
output "gitlab_web_url" {
  description = "GitLab web UI URL"
  value       = var.install_gitlab ? "http://localhost:${var.gitlab_web_host_port}" : "Not installed"
}

output "gitlab_ssh_url" {
  description = "GitLab SSH URL"
  value       = var.install_gitlab ? "ssh://git@localhost:${var.gitlab_ssh_host_port}" : "Not installed"
}

output "gitlab_registry_url" {
  description = "GitLab registry URL"
  value       = var.install_gitlab ? "localhost:${var.gitlab_registry_host_port}" : "Not installed"
}

output "gitlab_root_password_command" {
  description = "Command to retrieve GitLab root password"
  value       = var.install_gitlab ? module.gitlab[0].root_password_command : "Not installed"
}

# Rancher Outputs
output "rancher_http_url" {
  description = "Rancher HTTP URL"
  value       = var.install_rancher ? "http://localhost:${var.rancher_http_host_port}" : "Not installed"
}

output "rancher_https_url" {
  description = "Rancher HTTPS URL"
  value       = var.install_rancher ? "https://localhost:${var.rancher_https_host_port}" : "Not installed"
}

output "rancher_bootstrap_password" {
  description = "Rancher bootstrap password (change on first login)"
  value       = var.install_rancher ? var.rancher_bootstrap_password : "Not installed"
  sensitive   = true
}

# LocalStack Outputs
output "localstack_url" {
  description = "LocalStack service URL"
  value       = var.install_localstack ? "http://localhost:${var.localstack_host_port}" : "Not installed"
}

output "localstack_health_url" {
  description = "LocalStack health check URL"
  value       = var.install_localstack ? "http://localhost:${var.localstack_host_port}/_localstack/health" : "Not installed"
}

# Summary Output
output "summary" {
  description = "Summary of all services"
  value       = <<-EOT

    ========================================
    K3D Cluster Setup Complete!
    ========================================

    Cluster: ${module.k3d_cluster.cluster_name}
    Context: ${module.k3d_cluster.kubeconfig_context}
    Registry: ${module.k3d_cluster.registry_endpoint}

    Services:
    ${var.install_argocd ? "  - ArgoCD:     http://localhost:${var.argocd_host_port}" : ""}
    ${var.install_gitlab ? "  - GitLab:     http://localhost:${var.gitlab_web_host_port}" : ""}
    ${var.install_rancher ? "  - Rancher:    http://localhost:${var.rancher_http_host_port}" : ""}
    ${var.install_localstack ? "  - LocalStack: http://localhost:${var.localstack_host_port}" : ""}

    Credentials:
    ${var.install_argocd ? "  - ArgoCD admin password:\n    ${module.argocd[0].admin_password_command}" : ""}
    ${var.install_gitlab ? "  - GitLab root password:\n    ${module.gitlab[0].root_password_command}" : ""}
    ${var.install_rancher ? "  - Rancher bootstrap password:\n    terraform output rancher_bootstrap_password" : ""}

    Next Steps:
      1. Verify cluster: kubectl get nodes
      2. Check services: kubectl get pods --all-namespaces
      3. Access services via the URLs above

  EOT
}
