variable "namespace" {
  description = "Kubernetes namespace for ArgoCD Image Updater (should match ArgoCD namespace)"
  type        = string
  default     = "argocd"
}

variable "release_name" {
  description = "Helm release name"
  type        = string
  default     = "argocd-image-updater"
}

variable "chart_version" {
  description = "ArgoCD Image Updater Helm chart version"
  type        = string
  default     = ""
}

variable "registry_name" {
  description = "Name of the K3D registry"
  type        = string
}

variable "git_token" {
  description = "GitLab Project Access Token for Git write access (optional)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "depends_on_argocd" {
  description = "Dependency on ArgoCD installation"
  type        = any
  default     = null
}

variable "values_file" {
  description = "Path to Helm values YAML file (optional, will use inline values if not provided)"
  type        = string
  default     = ""
}
