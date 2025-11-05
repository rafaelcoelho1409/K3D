# K3D Cluster Configuration
variable "cluster_name" {
  description = "Name of the K3D cluster"
  type        = string
  default     = "master"
}

variable "k3s_version" {
  description = "K3s version to use"
  type        = string
  default     = "v1.28.5-k3s1"
}

variable "servers" {
  description = "Number of server nodes"
  type        = number
  default     = 1
}

variable "agents" {
  description = "Number of agent nodes"
  type        = number
  default     = 3
}

variable "registry_port" {
  description = "Port for the K3D registry"
  type        = number
  default     = 5000
}

# Service Installation Flags
variable "install_argocd" {
  description = "Whether to install ArgoCD"
  type        = bool
  default     = true
}

variable "install_argocd_image_updater" {
  description = "Whether to install ArgoCD Image Updater"
  type        = bool
  default     = true
}

variable "install_gitlab" {
  description = "Whether to install GitLab"
  type        = bool
  default     = true
}

variable "install_rancher" {
  description = "Whether to install Rancher"
  type        = bool
  default     = true
}

variable "install_localstack" {
  description = "Whether to install LocalStack"
  type        = bool
  default     = true
}

# ArgoCD Configuration
variable "argocd_host_port" {
  description = "Host port for ArgoCD web UI"
  type        = number
  default     = 9080
}

variable "argocd_node_port" {
  description = "NodePort for ArgoCD service"
  type        = number
  default     = 30090
}

# GitLab Configuration
variable "gitlab_web_host_port" {
  description = "Host port for GitLab web UI"
  type        = number
  default     = 8090
}

variable "gitlab_web_node_port" {
  description = "NodePort for GitLab web service"
  type        = number
  default     = 30082
}

variable "gitlab_ssh_host_port" {
  description = "Host port for GitLab SSH"
  type        = number
  default     = 2222
}

variable "gitlab_ssh_node_port" {
  description = "NodePort for GitLab SSH service"
  type        = number
  default     = 30022
}

variable "gitlab_registry_host_port" {
  description = "Host port for GitLab registry"
  type        = number
  default     = 5050
}

variable "gitlab_registry_node_port" {
  description = "NodePort for GitLab registry service"
  type        = number
  default     = 30050
}

# Rancher Configuration
variable "rancher_http_host_port" {
  description = "Host port for Rancher HTTP"
  type        = number
  default     = 7080
}

variable "rancher_http_node_port" {
  description = "NodePort for Rancher HTTP service"
  type        = number
  default     = 30080
}

variable "rancher_https_host_port" {
  description = "Host port for Rancher HTTPS"
  type        = number
  default     = 7443
}

variable "rancher_https_node_port" {
  description = "NodePort for Rancher HTTPS service"
  type        = number
  default     = 30443
}

variable "rancher_bootstrap_password" {
  description = "Bootstrap password for Rancher (change on first login)"
  type        = string
  default     = "admin"
  sensitive   = true
}

# LocalStack Configuration
variable "localstack_host_port" {
  description = "Host port for LocalStack"
  type        = number
  default     = 4566
}

variable "localstack_node_port" {
  description = "NodePort for LocalStack service"
  type        = number
  default     = 30566
}

# GitLab Image Updater Configuration
variable "gitlab_access_token" {
  description = "GitLab Project Access Token for ArgoCD Image Updater (optional)"
  type        = string
  default     = ""
  sensitive   = true
}
