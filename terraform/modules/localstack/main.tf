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
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

# Create LocalStack namespace
resource "kubernetes_namespace" "localstack" {
  metadata {
    name = var.namespace
  }
}

# Install LocalStack
resource "helm_release" "localstack" {
  name       = var.release_name
  repository = "https://localstack.github.io/helm-charts"
  chart      = "localstack"
  namespace  = kubernetes_namespace.localstack.metadata[0].name
  version    = var.chart_version != "" ? var.chart_version : null
  timeout    = 600

  wait             = true
  wait_for_jobs    = true
  create_namespace = false

  # Values from external YAML file
  values = [file(var.values_file)]
}

# Wait for LocalStack to be ready
resource "null_resource" "wait_for_localstack" {
  depends_on = [helm_release.localstack]

  provisioner "local-exec" {
    command = "kubectl wait --namespace ${var.namespace} --for=condition=ready pod --selector=app.kubernetes.io/name=localstack --timeout=300s"
  }
}
