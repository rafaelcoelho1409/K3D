#!/bin/bash

################################################################################
# k3d Port Addition Script
#
# Dynamically adds port mappings to an existing k3d cluster without recreation
# Uses k3d cluster edit --port-add command
#
# Usage: ./add-port.sh <host_port> <container_port> [node_filter] [description]
#
# Node Filter Options:
#   - loadbalancer (default) - Use k3d load balancer
#   - server:0 - Use server node
#   - agent:0 - Use first agent node
#   - agent:1 - Use second agent node
#   - agent:2 - Use third agent node
#
# Examples:
#   ./add-port.sh 8080 30080 loadbalancer "ArgoCD Web UI"
#   ./add-port.sh 8081 30081 agent:0 "Rancher Web UI"
#   ./add-port.sh 2222 30022 loadbalancer "GitLab SSH"
################################################################################

set -e

CLUSTER_NAME="master"

# Parse arguments
if [ $# -lt 2 ]; then
    echo "Usage: $0 <host_port> <container_port> [node_filter] [description]"
    echo ""
    echo "Node Filter Options:"
    echo "  - loadbalancer (default) - Use k3d load balancer"
    echo "  - server:0 - Use server node"
    echo "  - agent:0 - Use first agent node"
    echo "  - agent:1 - Use second agent node"
    echo "  - agent:2 - Use third agent node"
    echo ""
    echo "Examples:"
    echo "  $0 8080 30080 loadbalancer \"ArgoCD Web UI\""
    echo "  $0 8081 30081 agent:0 \"Rancher Web UI\""
    echo "  $0 8082 30082 loadbalancer \"GitLab Web UI\""
    echo "  $0 2222 30022 loadbalancer \"GitLab SSH\""
    echo "  $0 5050 30050 server:0 \"GitLab Registry\""
    echo ""
    exit 1
fi

HOST_PORT="$1"
CONTAINER_PORT="$2"
NODE_FILTER="${3:-loadbalancer}"
DESCRIPTION="${4:-Port mapping}"

echo "=========================================="
echo "Adding Port Mapping to k3d Cluster"
echo "=========================================="
echo ""
echo "  Cluster:        ${CLUSTER_NAME}"
echo "  Host Port:      ${HOST_PORT}"
echo "  Container Port: ${CONTAINER_PORT}"
echo "  Node Filter:    ${NODE_FILTER}"
echo "  Description:    ${DESCRIPTION}"
echo ""

# Verify cluster exists
if ! k3d cluster list 2>/dev/null | grep -q "^${CLUSTER_NAME}"; then
    echo "Error: Cluster '${CLUSTER_NAME}' does not exist"
    echo "Please create the cluster first: ./01-create-cluster.sh"
    exit 1
fi

# Check if port mapping already exists in k3d cluster
if docker port k3d-${CLUSTER_NAME}-serverlb 2>/dev/null | grep -q "0.0.0.0:${HOST_PORT}"; then
    echo "✓ Port ${HOST_PORT} is already mapped in the cluster"
    echo ""
    echo "Skipping port addition (already exists)"
    docker port k3d-${CLUSTER_NAME}-serverlb 2>/dev/null | grep "${HOST_PORT}" || true
    echo ""
    exit 0
fi

# Check if port is already in use on host (by another process)
if lsof -Pi :${HOST_PORT} -sTCP:LISTEN -t >/dev/null 2>&1; then
    echo "Error: Port ${HOST_PORT} is already in use on the host by another process"
    USING_PROCESS=$(lsof -Pi :${HOST_PORT} -sTCP:LISTEN -t | xargs ps -p | tail -n +2)
    echo "$USING_PROCESS"
    echo ""
    echo "Please free up the port or choose a different port"
    exit 1
fi

# Add port mapping to k3d cluster
echo "Adding port mapping to cluster..."
k3d cluster edit ${CLUSTER_NAME} --port-add ${HOST_PORT}:${CONTAINER_PORT}@${NODE_FILTER}

echo ""
echo "✓ Port mapping added successfully"
echo ""
echo "=========================================="
echo "Port Mapping Active"
echo "=========================================="
echo ""
echo "  ${DESCRIPTION}"
echo "  Access at: http://localhost:${HOST_PORT}"
echo ""
echo "Via Tailscale SSH tunnel from remote device:"
echo "  ssh -L ${HOST_PORT}:localhost:${HOST_PORT} <user>@<tailscale-hostname>"
echo "  Then open: http://localhost:${HOST_PORT} on remote device"
echo ""
echo "Current port mappings on loadbalancer:"
docker port k3d-${CLUSTER_NAME}-serverlb 2>/dev/null || echo "  (Unable to display port mappings)"
echo ""
echo "=========================================="
