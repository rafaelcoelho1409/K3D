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

# Patch GitLab services with specific NodePort values
# The GitLab Helm chart doesn't always respect NodePort values in values.yaml
resource "null_resource" "patch_gitlab_services" {
  depends_on = [null_resource.wait_for_gitlab]

  provisioner "local-exec" {
    command = <<-EOT
      # Patch webservice workhorse port (main UI - port 8181)
      kubectl patch service ${var.release_name}-webservice-default -n ${var.namespace} --type='json' -p='[
        {"op": "replace", "path": "/spec/ports/1/nodePort", "value": ${var.web_node_port}}
      ]' || echo "Warning: Failed to patch webservice port"

      # Patch gitlab-shell SSH port
      kubectl patch service ${var.release_name}-gitlab-shell -n ${var.namespace} --type='json' -p='[
        {"op": "replace", "path": "/spec/ports/0/nodePort", "value": ${var.ssh_node_port}}
      ]' || echo "Warning: Failed to patch SSH port"
    EOT
  }
}
