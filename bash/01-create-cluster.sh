#!/bin/bash

################################################################################
# k3d Master Cluster Creation Script
#
# Creates a local Kubernetes cluster for GitLab, ArgoCD, Rancher, and future apps
# - Direct localhost port access (no NGINX Ingress needed)
# - NodePort services for each application
# - Ports added dynamically via add-port.sh (no cluster recreation needed)
# - Works seamlessly over Tailscale SSH tunneling
# - Scalable without data loss
################################################################################

set -e

CLUSTER_NAME="master"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/k3d-config.yaml"

echo ""
echo "=========================================="
echo "k3d Master Cluster Setup"
echo "=========================================="
echo ""

# Step 1: Pre-flight checks
echo "Step 1/6: Running pre-flight checks..."

for cmd in k3d kubectl helm docker; do
    if ! command -v $cmd &> /dev/null; then
        echo "Error: $cmd is not installed"
        exit 1
    fi
done

if ! docker info &> /dev/null; then
    echo "Error: Docker daemon is not running"
    exit 1
fi

echo "✓ All prerequisites installed"
echo ""

# Step 2: Check existing cluster
echo "Step 2/6: Checking for existing cluster..."

if k3d cluster list 2>/dev/null | grep -q "^${CLUSTER_NAME}"; then
    echo "Warning: Cluster '${CLUSTER_NAME}' already exists"
    echo ""
    echo "1) Delete and recreate (will lose all data)"
    echo "2) Keep existing cluster and exit"
    echo ""
    read -p "Enter choice (1/2): " choice

    case $choice in
        1)
            echo "Deleting existing cluster..."
            k3d cluster delete ${CLUSTER_NAME}
            echo "✓ Cluster deleted"
            ;;
        2)
            echo "Using existing cluster"
            kubectl config use-context k3d-${CLUSTER_NAME}
            kubectl get nodes
            exit 0
            ;;
        *)
            echo "Error: Invalid choice"
            exit 1
            ;;
    esac
fi
echo ""

# Step 3: Validate config
echo "Step 3/6: Validating configuration..."

if [ ! -f "${CONFIG_FILE}" ]; then
    echo "Error: Config file not found: ${CONFIG_FILE}"
    exit 1
fi

echo "✓ Configuration validated"
echo ""

# Step 4: Create cluster
echo "Step 4/6: Creating k3d cluster (takes 2-3 minutes)..."
echo ""

k3d cluster create ${CLUSTER_NAME} --config "${CONFIG_FILE}" --wait

echo ""
echo "✓ Cluster created"
echo ""

# Step 5: Verify cluster
echo "Step 5/6: Verifying cluster health..."

kubectl wait --for=condition=Ready nodes --all --timeout=300s

NODES=$(kubectl get nodes --no-headers | wc -l)

echo "✓ All nodes ready"
echo ""

# Step 6: Make persistent
echo "Step 6/6: Configuring auto-restart..."

docker update --restart=unless-stopped $(docker ps -aq --filter "name=k3d-${CLUSTER_NAME}") 2>/dev/null

echo "✓ Cluster will auto-restart on reboot"
echo ""

# Summary
echo "=========================================="
echo "Cluster Created Successfully!"
echo "=========================================="
echo ""
echo "Cluster Information:"
echo "  Name:       ${CLUSTER_NAME}"
echo "  Nodes:      ${NODES} (1 server + 3 agents)"
echo "  Registry:   localhost:5000"
echo ""
echo "Current Status:"
kubectl get nodes
echo ""
echo "Storage Classes:"
kubectl get storageclass
echo ""
echo "Next Steps:"
echo "  1. Install applications (ArgoCD, Rancher, GitLab)"
echo "     cd ArgoCD && ./install.sh"
echo "     cd Rancher && ./install.sh"
echo "     cd GitLab && ./install.sh"
echo ""
echo "  2. Each application will automatically add its ports using add-port.sh"
echo ""
echo "  3. Access applications via localhost ports"
echo "     (Each install script will show the access URL)"
echo ""
echo "  4. For remote access via Tailscale SSH:"
echo "     ssh -L <local_port>:localhost:<local_port> <user>@<tailscale-host>"
echo ""
echo "Cluster is ready for application installation"
echo ""
