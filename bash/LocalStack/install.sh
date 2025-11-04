#!/bin/bash

# LocalStack Installation Script
# This script installs LocalStack in the master k3d cluster with NodePort access

set -e  # Exit on error

echo "=================================================="
echo "LocalStack Installation"
echo "=================================================="

# Configuration
NAMESPACE="localstack"
RELEASE_NAME="localstack"
CLUSTER_NAME="master"
HOST_PORT="4566"
NODE_PORT="30566"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ADD_PORT_SCRIPT="${SCRIPT_DIR}/../add-port.sh"
VALUES_FILE="${SCRIPT_DIR}/localstack-values.yaml"

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

echo "Step 1: Adding LocalStack Helm repository..."
helm repo add localstack https://localstack.github.io/helm-charts
helm repo update

echo "Step 2: Creating namespace..."
kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -

echo "Step 3: Installing LocalStack..."
helm install ${RELEASE_NAME} localstack/localstack \
  --namespace ${NAMESPACE} \
  --values "${VALUES_FILE}" \
  --timeout 600s \
  --wait

echo "Step 4: Waiting for LocalStack to be ready..."
kubectl wait --namespace ${NAMESPACE} \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/name=localstack \
  --timeout=300s

echo ""
echo "Step 5: Adding port mapping to k3d cluster..."
"${ADD_PORT_SCRIPT}" ${HOST_PORT} ${NODE_PORT} loadbalancer "LocalStack Edge Service"

echo ""
echo "Step 6: Ensuring cluster persistence across reboots..."
docker update --restart=unless-stopped $(docker ps -aq --filter "name=k3d-${CLUSTER_NAME}") 2>/dev/null
echo "✓ Cluster containers set to restart automatically"

echo ""
echo "=================================================="
echo "Installation Complete"
echo "=================================================="
echo ""
echo "LocalStack is now accessible at: http://localhost:${HOST_PORT}"
echo "Health check endpoint: http://localhost:${HOST_PORT}/_localstack/health"
echo ""
echo "AWS CLI Configuration for LocalStack:"
echo "  export AWS_ACCESS_KEY_ID=test"
echo "  export AWS_SECRET_ACCESS_KEY=test"
echo "  export AWS_DEFAULT_REGION=us-east-1"
echo "  export AWS_ENDPOINT_URL=http://localhost:${HOST_PORT}"
echo ""
echo "Test LocalStack with AWS CLI:"
echo "  aws --endpoint-url=http://localhost:${HOST_PORT} s3 mb s3://test-bucket"
echo "  aws --endpoint-url=http://localhost:${HOST_PORT} s3 ls"
echo ""
echo "Terraform Provider Configuration:"
echo "  provider \"aws\" {"
echo "    access_key                  = \"test\""
echo "    secret_key                  = \"test\""
echo "    region                      = \"us-east-1\""
echo "    skip_credentials_validation = true"
echo "    skip_metadata_api_check     = true"
echo "    skip_requesting_account_id  = true"
echo ""
echo "    endpoints {"
echo "      s3       = \"http://localhost:${HOST_PORT}\""
echo "      dynamodb = \"http://localhost:${HOST_PORT}\""
echo "      ec2      = \"http://localhost:${HOST_PORT}\""
echo "    }"
echo "  }"
echo ""
echo "LocalStack Status:"
kubectl get pods -n ${NAMESPACE}
echo ""
echo "Service Configuration:"
kubectl get svc -n ${NAMESPACE}
echo ""
echo "Useful Commands:"
echo "  Check logs: kubectl logs -f -n ${NAMESPACE} -l app.kubernetes.io/name=localstack"
echo "  Check health: curl http://localhost:${HOST_PORT}/_localstack/health | jq"
echo "  Restart: kubectl rollout restart deployment/${RELEASE_NAME} -n ${NAMESPACE}"
echo ""
echo "Access from remote device via Tailscale SSH:"
echo "  ssh -L ${HOST_PORT}:localhost:${HOST_PORT} <user>@<tailscale-hostname>"
echo "  Then open: http://localhost:${HOST_PORT}"
echo ""
echo "Documentation: https://docs.localstack.cloud"
echo ""
echo "=================================================="
