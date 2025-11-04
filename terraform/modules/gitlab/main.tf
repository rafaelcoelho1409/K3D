terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.24"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

# Create GitLab namespace
resource "kubernetes_namespace" "gitlab" {
  metadata {
    name = var.namespace
  }
}

# Install GitLab
resource "helm_release" "gitlab" {
  name       = var.release_name
  repository = "https://charts.gitlab.io/"
  chart      = "gitlab"
  namespace  = kubernetes_namespace.gitlab.metadata[0].name
  version    = var.chart_version != "" ? var.chart_version : null
  timeout    = 900

  wait             = true
  wait_for_jobs    = false
  create_namespace = false

  # Values from external YAML file
  values = [file(var.values_file)]
}

# Wait for GitLab webservice to be ready
resource "null_resource" "wait_for_gitlab" {
  depends_on = [helm_release.gitlab]

  provisioner "local-exec" {
    command = "kubectl wait --namespace ${var.namespace} --for=condition=ready pod --selector=app=webservice --timeout=600s || echo 'Warning: Timeout waiting for webservice'"
  }
}
