variable "namespace" {
  description = "Kubernetes namespace for GitLab"
  type        = string
  default     = "gitlab"
}

variable "release_name" {
  description = "Helm release name"
  type        = string
  default     = "gitlab"
}

variable "chart_version" {
  description = "GitLab Helm chart version"
  type        = string
  default     = ""
}

variable "web_node_port" {
  description = "NodePort for GitLab web service"
  type        = number
  default     = 30082
}

variable "ssh_node_port" {
  description = "NodePort for GitLab SSH service"
  type        = number
  default     = 30022
}

variable "registry_node_port" {
  description = "NodePort for GitLab registry service"
  type        = number
  default     = 30050
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
