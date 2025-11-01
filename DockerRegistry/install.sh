#!/bin/bash

# Docker Registry Installation Script
# This script installs Docker Registry in the master k3d cluster with NodePort access
#
# Port Architecture:
#   - Container listens on port 5000 (required for default health probes)
#   - Exposed via NodePort 30500
#   - k3d loadbalancer maps host port 5100 to NodePort 30500
#   - External access: localhost:5100
#   - Internal access: docker-registry.docker-registry.svc.cluster.local:5000
#
# Note: Using port 5100 externally to avoid conflict with k3d's built-in
#       master-registry which uses port 5000

set -e  # Exit on error

echo "=================================================="
echo "Docker Registry Installation"
echo "=================================================="

# Configuration
NAMESPACE="docker-registry"
RELEASE_NAME="docker-registry"
CLUSTER_NAME="master"
HOST_PORT="5100"
NODE_PORT="30500"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ADD_PORT_SCRIPT="${SCRIPT_DIR}/../add-port.sh"
VALUES_FILE="${SCRIPT_DIR}/registry-values.yaml"

# Verify we're connected to the master cluster
CURRENT_CONTEXT=$(kubectl config current-context)
if [[ "$CURRENT_CONTEXT" != "k3d-${CLUSTER_NAME}" ]]; then
    echo "Error: Not connected to k3d-${CLUSTER_NAME} cluster"
    echo "Current context: $CURRENT_CONTEXT"
    echo "Please run: kubectl config use-context k3d-${CLUSTER_NAME}"
    exit 1
fi

# Verify add-port.sh script exists
if [ ! -f "${ADD_PORT_SCRIPT}" ]; then
    echo "Error: add-port.sh script not found at ${ADD_PORT_SCRIPT}"
    exit 1
fi

# Verify values file exists
if [ ! -f "${VALUES_FILE}" ]; then
    echo "Error: Values file not found at ${VALUES_FILE}"
    exit 1
fi

echo "Step 1: Adding Docker Registry Helm repository..."
helm repo add twuni https://helm.twun.io
helm repo update

echo "Step 2: Checking for existing installation..."
if helm list -n ${NAMESPACE} 2>/dev/null | grep -q "${RELEASE_NAME}"; then
    echo "Warning: Docker Registry is already installed"
    read -p "Do you want to uninstall and reinstall? (y/n): " REINSTALL
    if [ "$REINSTALL" = "y" ]; then
        echo "Uninstalling existing Docker Registry..."
        helm uninstall ${RELEASE_NAME} -n ${NAMESPACE}
        kubectl delete namespace ${NAMESPACE} --timeout=120s || true
        sleep 5
    else
        echo "Installation cancelled"
        exit 0
    fi
fi

echo "Step 3: Creating namespace..."
kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -

echo "Step 4: Installing Docker Registry..."
helm install ${RELEASE_NAME} twuni/docker-registry \
  --namespace ${NAMESPACE} \
  --values "${VALUES_FILE}" \
  --timeout 300s \
  --wait

echo "Step 5: Waiting for Docker Registry to be ready..."
kubectl wait --namespace ${NAMESPACE} \
  --for=condition=available \
  --timeout=180s \
  deployment/docker-registry

echo ""
echo "Step 6: Adding port mapping to k3d cluster..."
"${ADD_PORT_SCRIPT}" ${HOST_PORT} ${NODE_PORT} loadbalancer "Docker Registry"

echo ""
echo "Step 7: Ensuring cluster persistence across reboots..."
docker update --restart=unless-stopped $(docker ps -aq --filter "name=k3d-${CLUSTER_NAME}") 2>/dev/null
echo "✓ Cluster containers set to restart automatically"

echo ""
echo "=================================================="
echo "Installation Complete"
echo "=================================================="
echo ""
echo "Docker Registry is now accessible at: localhost:${HOST_PORT}"
echo ""
echo "Registry Configuration:"
echo "  External URL (from host):    localhost:${HOST_PORT}"
echo "  Internal URL (from k8s):     docker-registry.docker-registry.svc.cluster.local:5000"
echo "  Container Port:              5000"
echo "  NodePort:                    ${NODE_PORT}"
echo ""
echo "Docker Registry Status:"
kubectl get pods -n ${NAMESPACE}
echo ""
echo "Service Configuration:"
kubectl get svc -n ${NAMESPACE}
echo ""
echo "Usage Examples:"
echo ""
echo "  1. Tag an image for this registry:"
echo "     docker tag myimage:latest localhost:${HOST_PORT}/myimage:latest"
echo ""
echo "  2. Push an image:"
echo "     docker push localhost:${HOST_PORT}/myimage:latest"
echo ""
echo "  3. Pull an image:"
echo "     docker pull localhost:${HOST_PORT}/myimage:latest"
echo ""
echo "  4. From GitLab CI (use internal URL):"
echo "     REGISTRY: docker-registry.docker-registry.svc.cluster.local:5000"
echo ""
echo "  5. List images in registry:"
echo "     curl http://localhost:${HOST_PORT}/v2/_catalog"
echo ""
echo "Access from remote device via Tailscale SSH:"
echo "  ssh -L ${HOST_PORT}:localhost:${HOST_PORT} <user>@<tailscale-hostname>"
echo "  Then use: localhost:${HOST_PORT}"
echo ""
echo "Note: This is an insecure registry for local development."
echo "      For production, configure TLS and authentication."
echo ""
echo "=================================================="
