variable "namespace" {
  description = "Kubernetes namespace for ArgoCD"
  type        = string
  default     = "argocd"
}

variable "release_name" {
  description = "Helm release name"
  type        = string
  default     = "argocd"
}

variable "chart_version" {
  description = "ArgoCD Helm chart version"
  type        = string
  default     = ""
}

variable "node_port_http" {
  description = "NodePort for ArgoCD HTTP service"
  type        = number
  default     = 30090
}

variable "node_port_https" {
  description = "NodePort for ArgoCD HTTPS service"
  type        = number
  default     = 30091
}

variable "cluster_name" {
  description = "Name of the K3D cluster (used for dependency)"
  type        = string
}

variable "values_file" {
  description = "Path to Helm values YAML file (optional, will use inline values if not provided)"
  type        = string
  default     = ""
}

variable "cluster_ready" {
  description = "Signal that the cluster API is ready (dependency)"
  type        = string
  default     = ""
}
