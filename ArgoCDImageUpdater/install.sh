#!/bin/bash

# ArgoCD Image Updater Installation Script
# This script installs ArgoCD Image Updater in the argocd namespace
#
# Purpose: Automatically update image tags in Git when new images are pushed to Docker Registry
# Flow: Docker Registry → Image Updater → Git commit → ArgoCD sync
#
# Prerequisites:
#   - ArgoCD must be installed
#   - Docker Registry must be running
#   - Git credentials (GitLab access token) must be configured

set -e  # Exit on error

echo "=================================================="
echo "ArgoCD Image Updater Installation"
echo "=================================================="

# Configuration
NAMESPACE="argocd"
RELEASE_NAME="argocd-image-updater"
CLUSTER_NAME="master"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VALUES_FILE="${SCRIPT_DIR}/image-updater-values.yaml"

# Verify we're connected to the master cluster
CURRENT_CONTEXT=$(kubectl config current-context)
if [[ "$CURRENT_CONTEXT" != "k3d-${CLUSTER_NAME}" ]]; then
    echo "Error: Not connected to k3d-${CLUSTER_NAME} cluster"
    echo "Current context: $CURRENT_CONTEXT"
    echo "Please run: kubectl config use-context k3d-${CLUSTER_NAME}"
    exit 1
fi

# Verify values file exists
if [ ! -f "${VALUES_FILE}" ]; then
    echo "Error: Values file not found at ${VALUES_FILE}"
    exit 1
fi

# Verify ArgoCD is installed
if ! kubectl get namespace ${NAMESPACE} >/dev/null 2>&1; then
    echo "Error: ArgoCD namespace '${NAMESPACE}' not found"
    echo "Please install ArgoCD first"
    exit 1
fi

if ! kubectl get deployment argocd-server -n ${NAMESPACE} >/dev/null 2>&1; then
    echo "Error: ArgoCD server not found in namespace '${NAMESPACE}'"
    echo "Please install ArgoCD first"
    exit 1
fi

echo "Step 1: Adding Argo Helm repository..."
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

echo "Step 2: Checking for existing installation..."
if helm list -n ${NAMESPACE} 2>/dev/null | grep -q "${RELEASE_NAME}"; then
    echo "Warning: ArgoCD Image Updater is already installed"
    read -p "Do you want to uninstall and reinstall? (y/n): " REINSTALL
    if [ "$REINSTALL" = "y" ]; then
        echo "Uninstalling existing ArgoCD Image Updater..."
        helm uninstall ${RELEASE_NAME} -n ${NAMESPACE}
        sleep 3
    else
        echo "Installation cancelled"
        exit 0
    fi
fi

echo ""
echo "Step 3: Creating Git credentials secret..."
echo ""
echo "ArgoCD Image Updater needs Git write access to update image tags."
echo "Please provide a GitLab Project Access Token with write_repository scope."
echo ""
read -p "Enter GitLab Project Access Token (or press Enter to skip): " GIT_TOKEN

if [ -n "$GIT_TOKEN" ]; then
    # Create Git credentials secret
    kubectl create secret generic git-creds \
      --namespace ${NAMESPACE} \
      --from-literal=username=gitlab-ci-token \
      --from-literal=password=${GIT_TOKEN} \
      --dry-run=client -o yaml | kubectl apply -f -
    echo "✓ Git credentials secret created"
else
    echo "⚠ Skipping Git credentials creation"
    echo "  You can create it later with:"
    echo "  kubectl create secret generic git-creds -n ${NAMESPACE} \\"
    echo "    --from-literal=username=gitlab-ci-token \\"
    echo "    --from-literal=password=<YOUR_TOKEN>"
fi

echo ""
echo "Step 4: Installing ArgoCD Image Updater..."
helm install ${RELEASE_NAME} argo/argocd-image-updater \
  --namespace ${NAMESPACE} \
  --values "${VALUES_FILE}" \
  --timeout 300s \
  --wait

echo ""
echo "Step 5: Waiting for ArgoCD Image Updater to be ready..."
kubectl wait --namespace ${NAMESPACE} \
  --for=condition=available \
  --timeout=180s \
  deployment/argocd-image-updater

echo ""
echo "Step 6: Ensuring cluster persistence across reboots..."
docker update --restart=unless-stopped $(docker ps -aq --filter "name=k3d-${CLUSTER_NAME}") 2>/dev/null
echo "✓ Cluster containers set to restart automatically"

echo ""
echo "=================================================="
echo "Installation Complete"
echo "=================================================="
echo ""
echo "ArgoCD Image Updater is now running!"
echo ""
echo "Configuration:"
echo "  Registry:         docker-registry.docker-registry.svc.cluster.local:5000"
echo "  ArgoCD Server:    argocd-server.argocd.svc.cluster.local"
echo "  Git User:         argocd-image-updater"
echo ""
echo "ArgoCD Image Updater Status:"
kubectl get pods -n ${NAMESPACE} -l app.kubernetes.io/name=argocd-image-updater
echo ""
echo "View logs:"
echo "  kubectl logs -n ${NAMESPACE} -l app.kubernetes.io/name=argocd-image-updater -f"
echo ""
echo "Next Steps:"
echo "1. Ensure Git credentials secret exists (if skipped above)"
echo "2. Annotate your ArgoCD Application with image update settings"
echo "3. Example annotation for COELHORealTime app:"
echo ""
echo "   argocd.argoproj.io/image-list: |"
echo "     fastapi=docker-registry.docker-registry.svc.cluster.local:5000/coelho-realtime-fastapi"
echo "     kafka=docker-registry.docker-registry.svc.cluster.local:5000/coelho-realtime-kafka"
echo "     mlflow=docker-registry.docker-registry.svc.cluster.local:5000/coelho-realtime-mlflow"
echo "     streamlit=docker-registry.docker-registry.svc.cluster.local:5000/coelho-realtime-streamlit"
echo ""
echo "=================================================="
