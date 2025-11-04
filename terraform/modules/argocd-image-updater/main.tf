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

# Create Git credentials secret if token is provided
resource "kubernetes_secret" "git_creds" {
  count = var.git_token != "" ? 1 : 0

  metadata {
    name      = "git-creds"
    namespace = var.namespace
  }

  data = {
    username = "gitlab-ci-token"
    password = var.git_token
  }

  type = "Opaque"
}

# Install ArgoCD Image Updater
resource "helm_release" "argocd_image_updater" {
  name       = var.release_name
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argocd-image-updater"
  namespace  = var.namespace
  version    = var.chart_version != "" ? var.chart_version : null
  timeout    = 300

  wait             = true
  wait_for_jobs    = true
  create_namespace = false

  # Values from external YAML file
  values = [file(var.values_file)]
}

# Wait for ArgoCD Image Updater to be ready
resource "null_resource" "wait_for_image_updater" {
  depends_on = [helm_release.argocd_image_updater]

  provisioner "local-exec" {
    command = "kubectl wait --namespace ${var.namespace} --for=condition=available --timeout=180s deployment/argocd-image-updater || true"
  }
}
