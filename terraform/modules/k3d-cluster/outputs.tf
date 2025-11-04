output "cluster_name" {
  description = "Name of the K3D cluster"
  value       = k3d_cluster.master.name
}

output "cluster_id" {
  description = "ID of the K3D cluster"
  value       = k3d_cluster.master.id
}

output "kubeconfig_path" {
  description = "Path to the kubeconfig file"
  value       = "~/.kube/config"
}

output "kubeconfig_context" {
  description = "Kubectl context for the cluster"
  value       = "k3d-${var.cluster_name}"
}

output "registry_endpoint" {
  description = "Endpoint for the K3D registry"
  value       = "localhost:${var.registry_port}"
}
