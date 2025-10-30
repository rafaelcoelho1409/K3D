#!/bin/bash

# ArgoCD Installation Script
# This script installs ArgoCD in the master k3d cluster with NodePort access

set -e  # Exit on error

echo "=================================================="
echo "ArgoCD Installation"
echo "=================================================="

# Configuration
NAMESPACE="argocd"
RELEASE_NAME="argocd"
CLUSTER_NAME="master"
HOST_PORT="9080"
NODE_PORT="30090"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ADD_PORT_SCRIPT="${SCRIPT_DIR}/../add-port.sh"
VALUES_FILE="${SCRIPT_DIR}/argocd-values.yaml"

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

echo "Step 1: Adding Argo Helm repository..."
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

echo "Step 2: Creating namespace..."
kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -

echo "Step 3: Installing ArgoCD..."
helm install ${RELEASE_NAME} argo/argo-cd \
  --namespace ${NAMESPACE} \
  --values "${VALUES_FILE}" \
  --timeout 600s \
  --wait

echo "Step 4: Waiting for ArgoCD to be ready..."
kubectl wait --namespace ${NAMESPACE} \
  --for=condition=available \
  --timeout=300s \
  deployment/argocd-server

echo ""
echo "Step 5: Adding port mapping to k3d cluster..."
"${ADD_PORT_SCRIPT}" ${HOST_PORT} ${NODE_PORT} loadbalancer "ArgoCD Web UI"

echo ""
echo "Step 6: Ensuring cluster persistence across reboots..."
docker update --restart=unless-stopped $(docker ps -aq --filter "name=k3d-${CLUSTER_NAME}") 2>/dev/null
echo "✓ Cluster containers set to restart automatically"

echo ""
echo "=================================================="
echo "Installation Complete"
echo "=================================================="
echo ""
echo "ArgoCD is now accessible at: http://localhost:${HOST_PORT}"
echo ""
echo "ArgoCD Credentials:"
echo "  Username: admin"
echo -n "  Password: "
kubectl -n ${NAMESPACE} get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
echo ""
echo ""
echo "CLI Login:"
echo "  argocd login localhost:${HOST_PORT} --username admin --insecure"
echo ""
echo "ArgoCD Status:"
kubectl get pods -n ${NAMESPACE}
echo ""
echo "Service Configuration:"
kubectl get svc -n ${NAMESPACE} argocd-server
echo ""
echo "Access from remote device via Tailscale SSH:"
echo "  ssh -L ${HOST_PORT}:localhost:${HOST_PORT} <user>@<tailscale-hostname>"
echo "  Then open: http://localhost:${HOST_PORT}"
echo ""
echo "=================================================="
