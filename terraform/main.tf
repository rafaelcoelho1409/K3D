# K3D Master Cluster - Terraform Configuration
#
# This configuration replicates the K3D cluster setup with all services:
# - K3D cluster with 1 server + 3 agents
# - ArgoCD
# - ArgoCD Image Updater
# - GitLab
# - Rancher
# - LocalStack
#
# Usage:
#   terraform init
#   terraform plan
#   terraform apply

# K3D Cluster Module
module "k3d_cluster" {
  source = "./modules/k3d"

  cluster_name  = var.cluster_name
  k3s_version   = var.k3s_version
  servers       = var.servers
  agents        = var.agents
  registry_port = var.registry_port

  # Port mappings for all services
  port_mappings = concat(
    var.install_argocd ? [
      {
        host_port      = var.argocd_host_port
        container_port = var.argocd_node_port
        node_filter    = "loadbalancer"
      }
    ] : [],
    var.install_gitlab ? [
      {
        host_port      = var.gitlab_web_host_port
        container_port = var.gitlab_web_node_port
        node_filter    = "loadbalancer"
      },
      {
        host_port      = var.gitlab_ssh_host_port
        container_port = var.gitlab_ssh_node_port
        node_filter    = "loadbalancer"
      },
      {
        host_port      = var.gitlab_registry_host_port
        container_port = var.gitlab_registry_node_port
        node_filter    = "loadbalancer"
      }
    ] : [],
    var.install_rancher ? [
      {
        host_port      = var.rancher_http_host_port
        container_port = var.rancher_http_node_port
        node_filter    = "loadbalancer"
      },
      {
        host_port      = var.rancher_https_host_port
        container_port = var.rancher_https_node_port
        node_filter    = "loadbalancer"
      }
    ] : [],
    var.install_localstack ? [
      {
        host_port      = var.localstack_host_port
        container_port = var.localstack_node_port
        node_filter    = "loadbalancer"
      }
    ] : []
  )
}

# ArgoCD Module
module "argocd" {
  count  = var.install_argocd ? 1 : 0
  source = "./modules/argocd"

  cluster_name   = var.cluster_name
  node_port_http = var.argocd_node_port

  # Use external values file from the module directory
  values_file = "${path.module}/modules/argocd/values.yaml"

  # Explicitly depend on cluster API being ready
  cluster_ready = module.k3d_cluster.cluster_ready
  depends_on    = [module.k3d_cluster]
}

# ArgoCD Image Updater Module
module "argocd_image_updater" {
  count  = var.install_argocd && var.install_argocd_image_updater ? 1 : 0
  source = "./modules/argocd-image-updater"

  namespace         = "argocd"
  registry_name     = "${var.cluster_name}-registry"
  git_token         = var.gitlab_access_token
  depends_on_argocd = module.argocd

  # Use external values file from the module directory
  values_file = "${path.module}/modules/argocd-image-updater/values.yaml"

  depends_on = [module.argocd]
}

# GitLab Module
module "gitlab" {
  count  = var.install_gitlab ? 1 : 0
  source = "./modules/gitlab"

  cluster_name       = var.cluster_name
  web_node_port      = var.gitlab_web_node_port
  ssh_node_port      = var.gitlab_ssh_node_port
  registry_node_port = var.gitlab_registry_node_port

  # Use external values file from the module directory
  values_file = "${path.module}/modules/gitlab/values.yaml"

  # Explicitly depend on cluster API being ready
  cluster_ready = module.k3d_cluster.cluster_ready
  depends_on    = [module.k3d_cluster]
}

# Rancher Module
module "rancher" {
  count  = var.install_rancher ? 1 : 0
  source = "./modules/rancher"

  cluster_name       = var.cluster_name
  http_node_port     = var.rancher_http_node_port
  https_node_port    = var.rancher_https_node_port
  bootstrap_password = var.rancher_bootstrap_password

  # Use external values file from the module directory
  values_file = "${path.module}/modules/rancher/values.yaml"

  # Explicitly depend on cluster API being ready
  cluster_ready = module.k3d_cluster.cluster_ready
  depends_on    = [module.k3d_cluster]
}

# LocalStack Module
module "localstack" {
  count  = var.install_localstack ? 1 : 0
  source = "./modules/localstack"

  cluster_name = var.cluster_name
  node_port    = var.localstack_node_port

  # Use external values file from the module directory
  values_file = "${path.module}/modules/localstack/values.yaml"

  # Explicitly depend on cluster API being ready
  cluster_ready = module.k3d_cluster.cluster_ready
  depends_on    = [module.k3d_cluster]
}

#To destroy all resources
#k3d cluster delete master
#terraform state rm $(terraform state list)
#terraform destroy