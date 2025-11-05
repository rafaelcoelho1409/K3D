#!/bin/bash
# Complete fresh start cleanup and deployment
# This script automates the two-stage deployment process required for fresh installations

echo "=========================================="
echo "Complete Fresh Start Cleanup"
echo "=========================================="
echo ""

# 1. Delete K3D cluster (if exists)
echo "Step 1: Deleting K3D cluster..."
k3d cluster delete master 2>/dev/null || echo "Cluster already deleted"

# 2. Clean Docker containers
echo ""
echo "Step 2: Cleaning Docker containers..."
docker ps -a | grep k3d | awk '{print $1}' | xargs -r docker rm -f 2>/dev/null || true

# 3. Remove all Terraform state
echo ""
echo "Step 3: Removing Terraform state..."
terraform state rm $(terraform state list) 2>/dev/null || true
rm -f terraform.tfstate terraform.tfstate.backup
rm -f terraform.tfstate.*.backup
ls -lh terraform.tfstate* 2>/dev/null || echo "No state files found"

# 4. Clean Terraform cache
echo ""
echo "Step 4: Cleaning Terraform cache..."
rm -rf .terraform/
rm -f .terraform.lock.hcl

# 5. Clean kubeconfig contexts
echo ""
echo "Step 5: Cleaning kubeconfig..."
kubectl config delete-context k3d-master 2>/dev/null || true
kubectl config delete-cluster k3d-master 2>/dev/null || true
kubectl config unset users.admin@k3d-master 2>/dev/null || true

echo ""
echo "=========================================="
echo "Cleanup Complete!"
echo "=========================================="
echo ""

# 6. Deploy infrastructure with two-stage approach
echo "=========================================="
echo "Starting Two-Stage Deployment"
echo "=========================================="
echo ""
echo "This two-stage approach prevents 'connection refused' errors"
echo "by creating the cluster before Kubernetes resources."
echo ""

# Stage 1: Initialize Terraform
echo "Stage 1/3: Initializing Terraform..."
terraform init

if [ $? -ne 0 ]; then
    echo "Error: Terraform init failed"
    exit 1
fi

echo ""
# Stage 2: Create K3D cluster first
echo "Stage 2/3: Creating K3D cluster..."
echo "This ensures the cluster exists before Kubernetes provider connects."
terraform apply -target=module.k3d_cluster -auto-approve

if [ $? -ne 0 ]; then
    echo "Error: K3D cluster creation failed"
    exit 1
fi

echo ""
# Stage 3: Deploy all services
echo "Stage 3/3: Deploying all services..."
echo "Now deploying ArgoCD, GitLab, Rancher, and LocalStack."
terraform apply

if [ $? -ne 0 ]; then
    echo "Error: Service deployment failed"
    exit 1
fi

echo ""
echo "=========================================="
echo "Deployment Complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "  1. Get service URLs:"
echo "     terraform output summary"
echo ""
echo "  2. Get credentials:"
echo "     terraform output argocd_admin_password_command"
echo "     terraform output gitlab_root_password_command"
echo ""
