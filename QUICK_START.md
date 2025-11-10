# Quick Start Guide

## Prerequisites

Ensure you have these tools installed (see [README.md](./README.md) for version requirements):

- Terraform
- k3d
- **kubectl** (Required - used for cluster checks and patching service ports)
- Helm
- Docker

## Installation

### Fresh Installation (Recommended)

For a **fresh installation** with no existing cluster:

```bash
cd terraform
./fresh-start.sh
```

The script automatically handles:
- Complete cleanup of old clusters and state
- Two-stage deployment (prevents connection errors)
- Initialization and deployment

**Why use this?** Prevents `connection refused` errors that occur when the Kubernetes provider tries to connect before the cluster exists.

### Manual Installation Steps

If you prefer manual control or are updating an existing setup:

#### 1. Initialize Terraform
```bash
cd terraform
terraform init
```

#### 2. Fresh Installation - Two-Stage Deployment
For fresh installations without an existing cluster:
```bash
# Stage 1: Create cluster first
terraform apply -target=module.k3d_cluster

# Stage 2: Deploy all services
terraform apply
```

#### 3. Standard Update (Existing Cluster)
If you already have a cluster running:
```bash
terraform apply
# Type 'yes' when prompted
```

#### 4. Get Service URLs
```bash
terraform output summary
```

## Customizing Services

### Easy Way: Edit YAML Files

Each service has a values YAML file you can edit:

```bash
# Customize ArgoCD
nano modules/argocd/values.yaml

# Customize GitLab
nano modules/gitlab/values.yaml

# Customize Rancher
nano modules/rancher/values.yaml

# Customize LocalStack
nano modules/localstack/values.yaml

# Apply changes
terraform apply
```

### Using Your Existing Values Files

**Option 1: Copy to Terraform (Recommended)**
```bash
# Copy your existing customized files
cp ../ArgoCD/argocd-values.yaml modules/argocd/values.yaml
cp ../GitLab/gitlab-values.yaml modules/gitlab/values.yaml
cp ../Rancher/rancher-values.yaml modules/rancher/values.yaml
cp ../LocalStack/localstack-values.yaml modules/localstack/values.yaml
```

**Option 2: Reference Original Files**

Edit `main.tf`:
```hcl
module "argocd" {
  source = "./modules/argocd"

  # Reference your original file location
  values_file = "${path.root}/../ArgoCD/argocd-values.yaml"
}
```

## Common Operations

### Access Services
```bash
# ArgoCD
open http://localhost:9080

# GitLab
open http://localhost:8090

# Rancher
open http://localhost:7080

# LocalStack
open http://localhost:4566
```

### Get Credentials
```bash
# ArgoCD admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d

# GitLab root password
kubectl get secret gitlab-gitlab-initial-root-password -n gitlab -o jsonpath='{.data.password}' | base64 -d

# Rancher bootstrap password (default: admin)
terraform output rancher_bootstrap_password
```

### Check Status
```bash
# All pods
kubectl get pods --all-namespaces

# Specific service
kubectl get pods -n argocd
kubectl get pods -n gitlab
kubectl get pods -n cattle-system
kubectl get pods -n localstack
```

### Disable a Service
```bash
# Don't install Rancher
terraform apply -var="install_rancher=false"

# Or edit terraform.tfvars
echo 'install_rancher = false' >> terraform.tfvars
terraform apply
```

### Destroy Everything
```bash
terraform destroy
# Type 'yes' when prompted
```

### Fresh Start (Clean Everything)
```bash
# Automated script (recommended)
./fresh-start.sh

# Or manual cleanup
k3d cluster delete master
terraform state rm $(terraform state list)
terraform destroy
```

## File Locations

### Values Files (Edit These!)
- ArgoCD: `modules/argocd/values.yaml`
- ArgoCD Image Updater: `modules/argocd-image-updater/values.yaml`
- GitLab: `modules/gitlab/values.yaml`
- Rancher: `modules/rancher/values.yaml`
- LocalStack: `modules/localstack/values.yaml`

### Configuration Files
- Main config: `main.tf`
- Variables: `variables.tf` and `terraform.tfvars`
- Outputs: `outputs.tf`

## Comparison: YAML vs Manual Values

| Feature | YAML Files (Default) | Inline Terraform |
|---------|---------------------|------------------|
| Ease of use | ✅ Simple to edit | ⚠️ HCL syntax required |
| Migration | ✅ Copy existing files | ❌ Must convert |
| Best for | General configuration | Dynamic values |

**Recommendation:** Use YAML files for 99% of use cases.

## Workflow

### Initial Setup
1. `terraform init` - Download providers
2. Edit `terraform.tfvars` if needed
3. `terraform apply` - Create everything

### Making Changes
1. Edit YAML files in `modules/*/`
2. `terraform plan` - Review changes
3. `terraform apply` - Apply changes

### Troubleshooting
```bash
# Force recreate a service
terraform taint 'module.argocd[0].helm_release.argocd'
terraform apply

# Check Terraform state
terraform state list

# View outputs
terraform output
```

## Example: Customize GitLab Resources

**File:** `modules/gitlab/values.yaml`

```yaml
gitlab:
  webservice:
    resources:
      requests:
        cpu: "1000m"
        memory: "4Gi"
      limits:
        cpu: "2000m"
        memory: "8Gi"
```

Then:
```bash
terraform apply
```

That's it!

## Need More Help?

- Full documentation: [README.md](./README.md)
- Helm values guide: [HELM_VALUES_GUIDE.md](./HELM_VALUES_GUIDE.md)
- Terraform docs: https://www.terraform.io/docs
