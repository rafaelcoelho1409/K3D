# Quick Start Guide

## Installation

### 1. Initialize Terraform
```bash
cd terraform
terraform init
```

### 2. Review the Plan
```bash
terraform plan
```

### 3. Deploy Everything
```bash
terraform apply
# Type 'yes' when prompted
```

### 4. Get Service URLs
```bash
terraform output summary
```

## Customizing Services

### Easy Way: Edit YAML Files

Each service has a values YAML file you can edit:

```bash
# Customize ArgoCD
nano modules/argocd/argocd-values.yaml

# Customize GitLab
nano modules/gitlab/gitlab-values.yaml

# Customize Rancher
nano modules/rancher/rancher-values.yaml

# Customize LocalStack
nano modules/localstack/localstack-values.yaml

# Apply changes
terraform apply
```

### Using Your Existing Values Files

**Option 1: Copy to Terraform (Recommended)**
```bash
# Copy your existing customized files
cp ../ArgoCD/argocd-values.yaml modules/argocd/
cp ../GitLab/gitlab-values.yaml modules/gitlab/
cp ../Rancher/rancher-values.yaml modules/rancher/
cp ../LocalStack/localstack-values.yaml modules/localstack/
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

## File Locations

### Values Files (Edit These!)
- ArgoCD: `modules/argocd/argocd-values.yaml`
- ArgoCD Image Updater: `modules/argocd-image-updater/image-updater-values.yaml`
- GitLab: `modules/gitlab/gitlab-values.yaml`
- Rancher: `modules/rancher/rancher-values.yaml`
- LocalStack: `modules/localstack/localstack-values.yaml`

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

**File:** `modules/gitlab/gitlab-values.yaml`

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
