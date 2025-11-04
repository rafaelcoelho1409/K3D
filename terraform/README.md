# K3D Master Cluster - Terraform Configuration

This Terraform configuration replicates your K3D cluster setup with all services installed and configured automatically.

## Features

- **K3D Cluster**: 1 server + 3 agents with local Docker registry
- **ArgoCD**: GitOps continuous delivery tool
- **ArgoCD Image Updater**: Automatically updates image tags in Git
- **GitLab**: Complete DevOps platform with CI/CD
- **Rancher**: Kubernetes management platform
- **LocalStack**: AWS service emulator for local development

## Prerequisites

Before running this Terraform configuration, ensure you have the following installed:

- [Terraform](https://www.terraform.io/downloads.html) >= 1.6.0
- [k3d](https://k3d.io/) >= 5.0.0
- [kubectl](https://kubernetes.io/docs/tasks/tools/) >= 1.28.0
- [helm](https://helm.sh/docs/intro/install/) >= 3.12.0
- [Docker](https://docs.docker.com/get-docker/) >= 20.10.0

## Quick Start

### 1. Initialize Terraform

```bash
cd terraform
terraform init
```

### 2. Review the Plan

```bash
terraform plan
```

### 3. Apply the Configuration

```bash
terraform apply
```

Type `yes` when prompted to confirm.

This will:
1. Create the K3D cluster (takes 2-3 minutes)
2. Install all services (takes 15-20 minutes total)
3. Configure port mappings and auto-restart

### 4. Access Your Services

After the apply completes, Terraform will output all service URLs and credentials:

```bash
terraform output summary
```

## Service Access URLs

By default, services are accessible at:

- **ArgoCD**: http://localhost:9080
- **GitLab**: http://localhost:8090
- **Rancher**: http://localhost:7080
- **LocalStack**: http://localhost:4566

## Retrieving Credentials

### ArgoCD
```bash
# Username: admin
terraform output argocd_admin_password_command
# Or run the command directly:
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
```

### GitLab
```bash
# Username: root
terraform output gitlab_root_password_command
# Or run the command directly:
kubectl get secret gitlab-gitlab-initial-root-password -n gitlab -o jsonpath='{.data.password}' | base64 -d
```

### Rancher
```bash
# Username: admin
# Password: admin (change on first login)
terraform output rancher_bootstrap_password
```

## Customization

### Using Variables File

Copy the example variables file and customize:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` to customize:
- Cluster configuration (servers, agents)
- Service ports
- Enable/disable specific services
- GitLab access token for Image Updater

### Selective Service Installation

You can disable specific services by setting variables:

```bash
terraform apply -var="install_rancher=false" -var="install_localstack=false"
```

Or in your `terraform.tfvars`:
```hcl
install_rancher    = false
install_localstack = false
```

## Configuration Structure

```
terraform/
├── main.tf                      # Main configuration
├── variables.tf                 # Input variables
├── outputs.tf                   # Output values
├── providers.tf                 # Provider configuration
├── versions.tf                  # Version requirements
├── terraform.tfvars.example     # Example variables
├── README.md                    # This file
├── HELM_VALUES_GUIDE.md         # Guide for customizing Helm values
└── modules/
    ├── k3d-cluster/             # K3D cluster module
    ├── argocd/
    │   ├── argocd-values.yaml   # ← Edit to customize ArgoCD
    │   ├── main.tf
    │   ├── outputs.tf
    │   └── variables.tf
    ├── argocd-image-updater/
    │   ├── image-updater-values.yaml  # ← Edit to customize Image Updater
    │   └── ...
    ├── gitlab/
    │   ├── gitlab-values.yaml   # ← Edit to customize GitLab
    │   └── ...
    ├── rancher/
    │   ├── rancher-values.yaml  # ← Edit to customize Rancher
    │   └── ...
    └── localstack/
        ├── localstack-values.yaml  # ← Edit to customize LocalStack
        └── ...
```

## Module Documentation

### K3D Cluster Module
Creates a K3D cluster with configurable servers, agents, and registry.

**Inputs:**
- `cluster_name` - Name of the cluster (default: "master")
- `k3s_version` - K3s version (default: "v1.28.5-k3s1")
- `servers` - Number of server nodes (default: 1)
- `agents` - Number of agent nodes (default: 3)
- `registry_port` - Registry port (default: 5000)

### ArgoCD Module
Installs ArgoCD with NodePort service.

**Inputs:**
- `namespace` - Kubernetes namespace (default: "argocd")
- `node_port_http` - HTTP NodePort (default: 30090)

### GitLab Module
Installs GitLab CE with GitLab Runner.

**Inputs:**
- `namespace` - Kubernetes namespace (default: "gitlab")
- `web_node_port` - Web UI NodePort (default: 30082)
- `ssh_node_port` - SSH NodePort (default: 30022)

### Rancher Module
Installs Rancher Server.

**Inputs:**
- `namespace` - Kubernetes namespace (default: "cattle-system")
- `http_node_port` - HTTP NodePort (default: 30080)
- `https_node_port` - HTTPS NodePort (default: 30443)
- `bootstrap_password` - Initial password (default: "admin")

### LocalStack Module
Installs LocalStack for AWS emulation.

**Inputs:**
- `namespace` - Kubernetes namespace (default: "localstack")
- `node_port` - Edge service NodePort (default: 30566)

## Troubleshooting

### Cluster Creation Fails
```bash
# Check Docker is running
docker info

# Check existing clusters
k3d cluster list

# Delete existing cluster if needed
k3d cluster delete master
terraform apply
```

### Service Not Ready
```bash
# Check pod status
kubectl get pods --all-namespaces

# Check specific service logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server

# Wait for all pods
kubectl wait --for=condition=ready pods --all --all-namespaces --timeout=600s
```

### Port Conflicts
```bash
# Check which process is using a port
lsof -i :9080

# Change port in terraform.tfvars
argocd_host_port = 9081
```

### GitLab Takes Long to Start
GitLab typically takes 10-15 minutes to fully initialize. Check progress:
```bash
kubectl get pods -n gitlab -w
```

## Destroying the Infrastructure

To tear down everything:

```bash
terraform destroy
```

Type `yes` when prompted. This will:
1. Delete all Helm releases
2. Delete all namespaces
3. Delete the K3D cluster
4. Clean up all Docker containers

## Remote Access via Tailscale

If you want to access services remotely via Tailscale SSH tunneling:

```bash
# Forward all service ports
ssh -L 9080:localhost:9080 \
    -L 8090:localhost:8090 \
    -L 7080:localhost:7080 \
    -L 4566:localhost:4566 \
    user@tailscale-hostname

# Then access services on your local machine at the same URLs
```

## Architecture

### Cluster Design
- **Server Node**: Runs control plane (API server, scheduler, controller)
- **Agent Nodes**: Run application workloads (3 nodes for distribution)
- **Registry**: Local Docker registry at localhost:5000
- **Storage**: local-path provisioner for persistent volumes

### Networking
- **Service Type**: NodePort (direct localhost access)
- **Ingress**: Disabled (Traefik disabled)
- **Load Balancer**: K3D serverlb for port mapping

### Port Mappings
All ports are mapped through K3D's load balancer:
- Host Port → K3D Serverlb → NodePort → Service → Pod

## Best Practices

1. **Resource Management**: Ensure Docker has at least 8GB RAM allocated
2. **Storage**: Monitor disk usage, especially for GitLab (50GB+ recommended)
3. **Backups**: Export important data before running `terraform destroy`
4. **Credentials**: Change default passwords on first login
5. **Updates**: Pin versions in terraform.tfvars for reproducibility

## Integration with Existing Scripts

This Terraform configuration replaces:
- `01-create-cluster.sh` → `module "k3d_cluster"`
- `ArgoCD/install.sh` → `module "argocd"`
- `GitLab/install.sh` → `module "gitlab"`
- `Rancher/install.sh` → `module "rancher"`
- `LocalStack/install.sh` → `module "localstack"`
- `add-port.sh` → Automatic port mapping in cluster config

## Advanced Configuration

### Custom Helm Values

**Recommended Approach:** Edit the YAML values files directly in each module directory:

```bash
# Example: Customize ArgoCD configuration
nano modules/argocd/argocd-values.yaml

# Example: Customize GitLab resources
nano modules/gitlab/gitlab-values.yaml
```

Then apply:
```bash
terraform apply
```

Each module directory contains a values YAML file:
- `modules/argocd/argocd-values.yaml`
- `modules/argocd-image-updater/image-updater-values.yaml`
- `modules/gitlab/gitlab-values.yaml`
- `modules/rancher/rancher-values.yaml`
- `modules/localstack/localstack-values.yaml`

**See [HELM_VALUES_GUIDE.md](./HELM_VALUES_GUIDE.md) for detailed customization examples.**

### Using Your Own Values Files

You can reference your existing values files from the original service directories:

```hcl
# In main.tf
module "argocd" {
  source = "./modules/argocd"

  # Option 1: Reference original file
  values_file = "${path.root}/../ArgoCD/argocd-values.yaml"

  # Option 2: Use module's file (default)
  # values_file = "${path.module}/modules/argocd/argocd-values.yaml"
}
```

### Additional Services

To add more services:
1. Create a new module in `modules/my-service/`
2. Add module call in `main.tf`
3. Add variables in `variables.tf`
4. Add outputs in `outputs.tf`

## Support

For issues or questions:
- K3D: https://k3d.io/
- Terraform: https://www.terraform.io/docs
- ArgoCD: https://argo-cd.readthedocs.io/
- GitLab: https://docs.gitlab.com/
- Rancher: https://rancher.com/docs/

## License

This configuration is provided as-is for use with your K3D cluster setup.
