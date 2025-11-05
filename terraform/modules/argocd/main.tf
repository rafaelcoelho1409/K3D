terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.38"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.1"
    }
  }
}

# Create ArgoCD namespace
resource "kubernetes_namespace" "argocd" {
  metadata {
    name = var.namespace
    annotations = {
      "cluster-ready" = var.cluster_ready
    }
  }
}

# Add Argo Helm repository
resource "helm_release" "argocd" {
  name       = var.release_name
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  namespace  = kubernetes_namespace.argocd.metadata[0].name
  version    = var.chart_version != "" ? var.chart_version : null
  timeout    = 600

  # Wait for resources to be ready
  wait             = true
  wait_for_jobs    = true
  create_namespace = false

  # Values from external YAML file
  values = [file(var.values_file)]
}

# Wait for ArgoCD server to be ready
resource "null_resource" "wait_for_argocd" {
  depends_on = [helm_release.argocd]

  provisioner "local-exec" {
    command = "kubectl wait --namespace ${var.namespace} --for=condition=available --timeout=300s deployment/argocd-server"
  }
}
