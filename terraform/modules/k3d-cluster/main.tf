terraform {
  required_providers {
    k3d = {
      source  = "pvotal-tech/k3d"
      version = "~> 0.0.7"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

# K3D Cluster
resource "k3d_cluster" "master" {
  name    = var.cluster_name
  servers = var.servers
  agents  = var.agents

  image = "rancher/k3s:${var.k3s_version}"

  # K3s server arguments
  k3s {
    extra_args {
      arg          = "--disable=traefik"
      node_filters = ["server:*"]
    }
  }

  # Registry configuration
  registries {
    create {
      name      = "${var.cluster_name}-registry"
      host      = "0.0.0.0"
      host_port = var.registry_port
    }
  }

  # Port mappings
  dynamic "port" {
    for_each = var.port_mappings
    content {
      host_port      = port.value.host_port
      container_port = port.value.container_port
      node_filters   = [port.value.node_filter]
    }
  }

  # K3D options
  k3d {
    disable_load_balancer = false
  }

  # Kubeconfig options
  kubeconfig {
    update_default_kubeconfig = true
    switch_current_context    = true
  }
}

# Wait for cluster to be ready
resource "null_resource" "wait_for_cluster" {
  depends_on = [k3d_cluster.master]

  provisioner "local-exec" {
    command = "kubectl wait --for=condition=Ready nodes --all --timeout=300s --context=k3d-${var.cluster_name}"
  }
}

# Configure auto-restart for cluster containers
resource "null_resource" "configure_auto_restart" {
  depends_on = [null_resource.wait_for_cluster]

  provisioner "local-exec" {
    command = "docker update --restart=unless-stopped $(docker ps -aq --filter 'name=k3d-${var.cluster_name}') 2>/dev/null || true"
  }

  # Trigger on cluster changes
  triggers = {
    cluster_id = k3d_cluster.master.id
  }
}
