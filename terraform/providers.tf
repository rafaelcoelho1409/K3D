# K3D Provider
provider "k3d" {}

# Kubernetes Provider
# Configured to use the kubeconfig from the K3D cluster
# The K3D cluster automatically switches context when created
provider "kubernetes" {
  config_path = "~/.kube/config"
}

# Helm Provider
# Configured to use the kubeconfig from the K3D cluster
# The K3D cluster automatically switches context when created
provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}
