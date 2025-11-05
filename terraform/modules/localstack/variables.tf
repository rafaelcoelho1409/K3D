variable "namespace" {
  description = "Kubernetes namespace for LocalStack"
  type        = string
  default     = "localstack"
}

variable "release_name" {
  description = "Helm release name"
  type        = string
  default     = "localstack"
}

variable "chart_version" {
  description = "LocalStack Helm chart version"
  type        = string
  default     = ""
}

variable "node_port" {
  description = "NodePort for LocalStack edge service"
  type        = number
  default     = 30566
}

variable "localstack_image_tag" {
  description = "LocalStack image tag"
  type        = string
  default     = "3.0"
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
