# Windows Compatibility Guide

## Overview

The Terraform configuration is **95% compatible** with Windows. This guide covers what works out-of-the-box and what needs adjustment.

## Prerequisites for Windows

### Required Software

1. **Docker Desktop for Windows**
   ```powershell
   # Download from: https://docs.docker.com/desktop/install/windows-install/
   # Or via Chocolatey:
   choco install docker-desktop
   ```

2. **k3d CLI**
   ```powershell
   # Via Chocolatey
   choco install k3d

   # Via Scoop
   scoop install k3d
   ```

3. **kubectl** (**Required**)
   ```powershell
   choco install kubernetes-cli
   # OR
   scoop install kubectl
   ```

   **Why Required?** kubectl is used by Terraform provisioners to:
   - Wait for cluster API readiness (`kubectl cluster-info`, `kubectl wait`)
   - Patch service ports for GitLab and Rancher (`kubectl patch`)
   - Manage kubeconfig contexts (`kubectl config`)

4. **Helm**
   ```powershell
   choco install kubernetes-helm
   # OR
   scoop install helm
   ```

5. **Terraform**
   ```powershell
   choco install terraform
   # OR
   scoop install terraform
   ```

## What Works Out-of-the-Box

✅ All Terraform `.tf` files
✅ All YAML configuration files
✅ Terraform providers (auto-downloaded)
✅ K3D cluster creation
✅ Helm chart installations
✅ Kubernetes resource management
✅ Port mappings
✅ Service access via localhost

## Known Limitation

### Auto-Restart on Reboot

**Issue:** One command in `modules/k3d/main.tf` uses Linux-specific shell syntax:

```bash
docker update --restart=unless-stopped $(docker ps -aq --filter 'name=k3d-${var.cluster_name}') 2>/dev/null || true
```

**Impact on Windows:**
- Command may fail during `terraform apply`
- Cluster will still be created successfully ✅
- Only difference: Cluster won't auto-restart after system reboot

**Workaround (Manual):**

After running `terraform apply`, manually set auto-restart in PowerShell:

```powershell
# Get all cluster containers
$containers = docker ps -aq --filter "name=k3d-master_tf"

# Set auto-restart on each
foreach ($container in $containers) {
    docker update --restart=unless-stopped $container
}
```

Or in CMD:
```cmd
FOR /F %i IN ('docker ps -aq --filter "name=k3d-master_tf"') DO docker update --restart=unless-stopped %i
```

**Alternative (Recommended for Windows):**

Edit `terraform/modules/k3d/main.tf` and comment out the auto-restart resource:

```hcl
# Configure auto-restart for cluster containers
# Note: This may not work on Windows - run manually if needed
resource "null_resource" "configure_auto_restart" {
  depends_on = [null_resource.wait_for_cluster]

  # Uncomment on Linux, comment on Windows
  # provisioner "local-exec" {
  #   command = "docker update --restart=unless-stopped $(docker ps -aq --filter 'name=k3d-${var.cluster_name}') 2>/dev/null || true"
  # }

  # Trigger on cluster changes
  triggers = {
    cluster_id = k3d_cluster.master.id
  }
}
```

## Line Endings (Git on Windows)

**Issue:** Git on Windows may convert LF to CRLF, which can cause issues.

**Solution:** Create `.gitattributes` in the terraform directory:

```bash
# In terraform/.gitattributes
*.tf text eol=lf
*.yaml text eol=lf
*.yml text eol=lf
*.md text eol=lf
```

## Path Differences

**No action needed!** Terraform handles path differences automatically:

| OS | Kubeconfig Path | Terraform Reference |
|----|----------------|-------------------|
| Linux | `/home/user/.kube/config` | `~/.kube/config` |
| Windows | `C:\Users\user\.kube\config` | `~/.kube/config` |

Terraform's `~` expands correctly on both platforms.

## Running on Windows

### Fresh Installation

**Note:** The `fresh-start.sh` script is a Bash script and won't run directly in PowerShell/CMD.

**Option 1: Use WSL (Windows Subsystem for Linux)**

If you have WSL installed with Docker integration:
```bash
# In WSL terminal
cd /mnt/c/path/to/K3D/terraform
./fresh-start.sh
```

**Option 2: Manual Two-Stage Deployment**

For fresh installations on Windows without WSL, use the manual two-stage approach:

#### PowerShell (Recommended)

```powershell
# Navigate to terraform directory
cd C:\path\to\K3D\terraform

# Clean up old cluster (if exists)
k3d cluster delete master

# Clean up Terraform state
$stateList = terraform state list
if ($stateList) {
    terraform state rm $stateList
}
Remove-Item -Force terraform.tfstate* -ErrorAction SilentlyContinue

# Two-stage deployment
terraform init
terraform apply -target=module.k3d_cluster -auto-approve
terraform apply

# After apply, manually set auto-restart (optional)
docker ps -aq --filter "name=k3d-master" | ForEach-Object {
    docker update --restart=unless-stopped $_
}
```

#### Command Prompt (CMD)

```cmd
cd C:\path\to\K3D\terraform

REM Clean up old cluster
k3d cluster delete master

REM Clean up Terraform state
FOR /F %i IN ('terraform state list') DO terraform state rm %i
del terraform.tfstate*

REM Two-stage deployment
terraform init
terraform apply -target=module.k3d_cluster -auto-approve
terraform apply

REM After apply, set auto-restart (optional)
FOR /F %i IN ('docker ps -aq --filter "name=k3d-master"') DO docker update --restart=unless-stopped %i
```

### Standard Updates (Existing Cluster)

If you already have a cluster running and just want to update:

#### PowerShell

```powershell
# Navigate to terraform directory
cd C:\path\to\K3D\terraform

# Apply changes
terraform apply

# After apply, manually set auto-restart (optional)
docker ps -aq --filter "name=k3d-master" | ForEach-Object {
    docker update --restart=unless-stopped $_
}
```

### Command Prompt (CMD)

```cmd
cd C:\path\to\K3D\terraform

terraform init
terraform plan
terraform apply

REM After apply, manually set auto-restart (optional)
FOR /F %i IN ('docker ps -aq --filter "name=k3d-master_tf"') DO docker update --restart=unless-stopped %i
```

## Testing on Windows

```powershell
# 1. Check cluster is running
k3d cluster list

# 2. Check all pods
kubectl get pods --all-namespaces

# 3. Verify port mappings
docker port k3d-master_tf-serverlb

# 4. Test services
Invoke-WebRequest http://localhost:9080  # ArgoCD
Invoke-WebRequest http://localhost:8090  # GitLab
Invoke-WebRequest http://localhost:4566/_localstack/health  # LocalStack

# 5. Get credentials
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }
```

## Troubleshooting on Windows

### Docker Desktop Not Running
```powershell
# Check if Docker is running
docker info

# If not, start Docker Desktop from Start Menu
```

### WSL2 Backend Issues
```powershell
# Ensure WSL2 is enabled
wsl --list --verbose

# Update WSL2 if needed
wsl --update
```

### Port Already in Use
```powershell
# Check what's using a port
netstat -ano | findstr :9080

# Kill the process (replace PID)
taskkill /PID <PID> /F
```

### Terraform Provider Download Issues
```powershell
# Clear Terraform cache
Remove-Item -Recurse -Force .terraform

# Re-initialize
terraform init
```

## Platform-Specific Optimizations

### Windows Performance Tips

1. **Use WSL2 Backend** (Docker Desktop setting)
2. **Allocate enough resources** (Docker Desktop → Settings → Resources)
   - CPUs: 4+
   - Memory: 8GB+
   - Disk: 50GB+

3. **Disable Windows Defender exclusions** for:
   - `C:\Users\<user>\.kube`
   - `C:\ProgramData\Docker`
   - Your project directory

## Summary

| Feature | Linux | Windows | Fix Required |
|---------|-------|---------|--------------|
| Cluster creation | ✅ | ✅ | No |
| Service installation | ✅ | ✅ | No |
| Port mapping | ✅ | ✅ | No |
| Service access | ✅ | ✅ | No |
| Auto-restart | ✅ | ⚠️ | Manual (optional) |

**Bottom Line:** The Terraform configuration works on Windows with one minor limitation (auto-restart). You can either:
1. Live without auto-restart (cluster won't restart after reboot)
2. Run the manual PowerShell command after `terraform apply`
3. Comment out the problematic resource

**Recommendation:** Use the configuration as-is on Windows. The auto-restart is a "nice-to-have" feature, not critical for functionality.
