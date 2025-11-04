output "namespace" {
  description = "ArgoCD Image Updater namespace"
  value       = var.namespace
}

output "release_name" {
  description = "ArgoCD Image Updater Helm release name"
  value       = helm_release.argocd_image_updater.name
}

output "git_creds_created" {
  description = "Whether Git credentials secret was created"
  value       = var.git_token != "" ? true : false
}
