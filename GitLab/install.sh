#!/bin/bash

# GitLab Installation Script
# This script installs GitLab in the master k3d cluster with NodePort access

set -e  # Exit on error

echo "=================================================="
echo "GitLab Installation"
echo "=================================================="

# Configuration
NAMESPACE="gitlab"
RELEASE_NAME="gitlab"
CLUSTER_NAME="master"
WEB_HOST_PORT="8090"
WEB_NODE_PORT="30082"
SSH_HOST_PORT="2222"
SSH_NODE_PORT="30022"
REGISTRY_HOST_PORT="5050"
REGISTRY_NODE_PORT="30050"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VALUES_FILE="${SCRIPT_DIR}/gitlab-values.yaml"
ADD_PORT_SCRIPT="${SCRIPT_DIR}/../add-port.sh"

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

# Check if values file exists
if [ ! -f "${VALUES_FILE}" ]; then
    echo "Error: Values file not found: ${VALUES_FILE}"
    exit 1
fi

echo "Step 1: Adding GitLab Helm repository..."
helm repo add gitlab https://charts.gitlab.io/
helm repo update

echo "Step 2: Checking for existing installation..."
if helm list -n ${NAMESPACE} 2>/dev/null | grep -q "${RELEASE_NAME}"; then
    echo "Warning: GitLab is already installed"
    read -p "Do you want to uninstall and reinstall? (y/n): " REINSTALL
    if [ "$REINSTALL" = "y" ]; then
        echo "Uninstalling existing GitLab..."
        helm uninstall ${RELEASE_NAME} -n ${NAMESPACE}
        kubectl delete namespace ${NAMESPACE} --timeout=120s || true
        sleep 10
    else
        echo "Installation cancelled"
        exit 0
    fi
fi

echo "Step 3: Creating namespace..."
kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -

echo "Step 4: Installing GitLab (this takes 10-15 minutes)..."
echo "Using values file: ${VALUES_FILE}"
helm install ${RELEASE_NAME} gitlab/gitlab \
  --namespace ${NAMESPACE} \
  --timeout 900s \
  --values "${VALUES_FILE}" \
  --wait

echo ""
echo "Step 5: Waiting for GitLab to be fully ready..."
kubectl wait --namespace ${NAMESPACE} \
  --for=condition=ready pod \
  --selector=app=webservice \
  --timeout=600s || echo "Warning: Timeout waiting for webservice, but installation may still succeed"

echo ""
echo "Step 6: Patching GitLab services with specific NodePort values..."
# Patch webservice workhorse port (main UI - port 8181)
kubectl patch service gitlab-webservice-default -n ${NAMESPACE} --type='json' -p='[
  {"op": "replace", "path": "/spec/ports/1/nodePort", "value": '${WEB_NODE_PORT}'}
]' || echo "Warning: Failed to patch webservice port, may already be set"

# Patch gitlab-shell SSH port
kubectl patch service gitlab-gitlab-shell -n ${NAMESPACE} --type='json' -p='[
  {"op": "replace", "path": "/spec/ports/0/nodePort", "value": '${SSH_NODE_PORT}'}
]' || echo "Warning: Failed to patch SSH port, may already be set"

# Patch registry port
kubectl patch service gitlab-registry -n ${NAMESPACE} --type='json' -p='[
  {"op": "replace", "path": "/spec/ports/0/nodePort", "value": '${REGISTRY_NODE_PORT}'}
]' || echo "Warning: Failed to patch registry port, may already be set"

echo ""
echo "Step 7: Adding port mappings to k3d cluster..."
"${ADD_PORT_SCRIPT}" ${WEB_HOST_PORT} ${WEB_NODE_PORT} loadbalancer "GitLab Web UI"
"${ADD_PORT_SCRIPT}" ${SSH_HOST_PORT} ${SSH_NODE_PORT} loadbalancer "GitLab SSH"
"${ADD_PORT_SCRIPT}" ${REGISTRY_HOST_PORT} ${REGISTRY_NODE_PORT} loadbalancer "GitLab Registry"

echo ""
echo "Step 8: Ensuring cluster persistence across reboots..."
docker update --restart=unless-stopped $(docker ps -aq --filter "name=k3d-${CLUSTER_NAME}") 2>/dev/null
echo "✓ Cluster containers set to restart automatically"

echo ""
echo "=================================================="
echo "Installation Complete"
echo "=================================================="
echo ""
echo "GitLab is now accessible at:"
echo "  Web UI:   http://localhost:${WEB_HOST_PORT}"
echo "  SSH:      ssh://git@localhost:${SSH_HOST_PORT}"
echo "  Registry: localhost:${REGISTRY_HOST_PORT}"
echo ""
echo "GitLab Root Credentials:"
echo "  Username: root"
echo -n "  Password: "
kubectl get secret ${RELEASE_NAME}-gitlab-initial-root-password -n ${NAMESPACE} -o jsonpath='{.data.password}' 2>/dev/null | base64 -d || echo "(not ready yet, check in a few minutes)"
echo ""
echo ""
echo "GitLab Status:"
kubectl get pods -n ${NAMESPACE}
echo ""
echo "Service Configuration:"
kubectl get svc -n ${NAMESPACE} | grep -E 'NAME|webservice|gitlab-shell|registry'
echo ""
echo "Access from remote device via Tailscale SSH:"
echo "  ssh -L ${WEB_HOST_PORT}:localhost:${WEB_HOST_PORT} -L ${SSH_HOST_PORT}:localhost:${SSH_HOST_PORT} <user>@<tailscale-hostname>"
echo "  Then open: http://localhost:${WEB_HOST_PORT}"
echo ""
echo "Git clone via SSH (from remote device):"
echo "  git clone ssh://git@localhost:${SSH_HOST_PORT}/root/your-repo.git"
echo ""
echo "Note: GitLab may take 5-10 more minutes to fully initialize"
echo "      Monitor with: kubectl get pods -n gitlab -w"
echo ""
echo "=================================================="
