#!/bin/bash

# Rancher Installation Script
# This script installs Rancher in the master k3d cluster with NodePort access

set -e  # Exit on error

echo "=================================================="
echo "Rancher Installation"
echo "=================================================="

# Configuration
NAMESPACE="cattle-system"
RELEASE_NAME="rancher"
CLUSTER_NAME="master"
HOST_PORT_HTTP="7080"
HOST_PORT_HTTPS="7443"
NODE_PORT_HTTP="30080"
NODE_PORT_HTTPS="30443"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ADD_PORT_SCRIPT="${SCRIPT_DIR}/../add-port.sh"
VALUES_FILE="${SCRIPT_DIR}/rancher-values.yaml"

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

echo "Step 1: Adding Rancher Helm repository..."
helm repo add rancher-stable https://releases.rancher.com/server-charts/stable
helm repo update

echo "Step 2: Creating namespace..."
kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -

echo "Step 3: Installing Rancher..."
helm install ${RELEASE_NAME} rancher-stable/rancher \
  --namespace ${NAMESPACE} \
  --values "${VALUES_FILE}" \
  --timeout 600s \
  --wait

echo "Step 4: Patching Rancher service with specific NodePort values..."
kubectl patch service ${RELEASE_NAME} -n ${NAMESPACE} --type='json' -p='[
  {"op": "replace", "path": "/spec/ports/0/nodePort", "value": '${NODE_PORT_HTTP}'},
  {"op": "replace", "path": "/spec/ports/1/nodePort", "value": '${NODE_PORT_HTTPS}'}
]'

echo "Step 5: Waiting for Rancher to be ready..."
kubectl wait --namespace ${NAMESPACE} \
  --for=condition=ready pod \
  --selector=app=rancher \
  --timeout=300s

echo ""
echo "Step 6: Adding port mapping to k3d cluster..."
"${ADD_PORT_SCRIPT}" ${HOST_PORT_HTTP} ${NODE_PORT_HTTP} loadbalancer "Rancher Web UI (HTTP)"
"${ADD_PORT_SCRIPT}" ${HOST_PORT_HTTPS} ${NODE_PORT_HTTPS} loadbalancer "Rancher Web UI (HTTPS)"

echo ""
echo "Step 7: Ensuring cluster persistence across reboots..."
docker update --restart=unless-stopped $(docker ps -aq --filter "name=k3d-${CLUSTER_NAME}") 2>/dev/null
echo "✓ Cluster containers set to restart automatically"

echo ""
echo "=================================================="
echo "Installation Complete"
echo "=================================================="
echo ""
echo "Rancher is now accessible at: http://localhost:${HOST_PORT_HTTP} (HTTP)"
echo "Rancher is now accessible at: http://localhost:${HOST_PORT_HTTPS} (HTTPS)"
echo ""
echo "Rancher Credentials:"
echo "  Initial Bootstrap Password: admin"
echo "  You will be prompted to set a new password on first login"
echo ""
echo "Rancher Status:"
kubectl get pods -n ${NAMESPACE}
echo ""
echo "Service Configuration:"
kubectl get svc -n ${NAMESPACE}
echo ""
echo "Access from remote device via Tailscale SSH:"
echo "  ssh -L ${HOST_PORT_HTTP}:localhost:${HOST_PORT_HTTP} <user>@<tailscale-hostname>"
echo "  Then open: http://localhost:${HOST_PORT}"
echo "  ssh -L ${HOST_PORT_HTTPS}:localhost:${HOST_PORT_HTTPS} <user>@<tailscale-hostname>"
echo "  Then open: http://localhost:${HOST_PORT_HTTPS}"
echo ""
echo "=================================================="
