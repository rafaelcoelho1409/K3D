# Helm Values Configuration Guide

This guide explains how to customize Helm chart values for each service in the K3D cluster.

## Overview

Each Terraform module supports **two approaches** for configuring Helm chart values:

1. **External YAML Files** (Default & Recommended)
2. **Inline Terraform Values** (Fallback)

## Approach 1: External YAML Files (Recommended)

This is the **default and recommended approach** because:
- Maintains a single source of truth
- Easier to edit and maintain
- More familiar YAML syntax
- Can use existing values files from shell scripts

### How It Works

Each module directory contains a values YAML file:

```
terraform/modules/
├── argocd/
│   ├── values.yaml          ← Edit this file
│   ├── main.tf
│   └── ...
├── gitlab/
│   ├── values.yaml          ← Edit this file
│   ├── main.tf
│   └── ...
```

The `main.tf` configuration automatically references these files:

```hcl
module "argocd" {
  source = "./modules/argocd"

  # Uses the YAML file from the module directory
  values_file = "${path.module}/modules/argocd/values.yaml"
}
```

### Customizing Helm Values

To customize a service's configuration:

1. **Edit the YAML file directly:**

```bash
# Example: Edit ArgoCD values
nano terraform/modules/argocd/values.yaml
```

2. **Apply the changes:**

```bash
terraform apply
```

That's it! Terraform will use your updated YAML file.

### Values Files Location

| Service | Values File Location |
|---------|---------------------|
| ArgoCD | `modules/argocd/values.yaml` |
| ArgoCD Image Updater | `modules/argocd-image-updater/values.yaml` |
| GitLab | `modules/gitlab/values.yaml` |
| Rancher | `modules/rancher/values.yaml` |
| LocalStack | `modules/localstack/values.yaml` |

### Example: Customizing ArgoCD

**File:** `modules/argocd/values.yaml`

```yaml
# Increase replicas for high availability
server:
  replicas: 3  # Changed from default
  service:
    type: NodePort
    nodePortHttp: 30090
    nodePortHttps: 30091
  extraArgs:
    - --insecure
  metrics:
    enabled: true
    service:
      type: ClusterIP

# Enable Redis HA
redis-ha:
  enabled: true
```

Then run:
```bash
terraform apply
```

### Using Your Existing Values Files

If you already have customized values files from the original setup, you can use them directly:

**Option A: Copy to module directory (Recommended)**
```bash
cp /path/to/my-custom-argocd-values.yaml terraform/modules/argocd/values.yaml
```

**Option B: Reference external file**

Edit `main.tf`:
```hcl
module "argocd" {
  source = "./modules/argocd"

  # Reference your custom file location
  values_file = "/path/to/my-custom-argocd-values.yaml"
  # Or relative to terraform directory:
  # values_file = "${path.root}/../ArgoCD/argocd-values.yaml"
}
```

## Approach 2: Inline Terraform Values (Fallback)

If you prefer to manage values directly in Terraform code, you can omit the `values_file` parameter.

### Disabling External YAML Files

Edit `main.tf` and remove or comment out the `values_file` line:

```hcl
module "argocd" {
  source = "./modules/argocd"

  cluster_name   = var.cluster_name
  node_port_http = var.argocd_node_port

  # values_file = "${path.module}/modules/argocd/values.yaml"  # Commented out

  depends_on = [module.k3d_cluster]
}
```

The module will then use the inline HCL values defined in `modules/argocd/main.tf`.

### Customizing Inline Values

Edit the module's `main.tf` file:

**File:** `modules/argocd/main.tf`

```hcl
resource "helm_release" "argocd" {
  # ... other configuration ...

  values = var.values_file != "" ? [
    file(var.values_file)
  ] : [
    yamlencode({
      # Edit these inline values
      server = {
        replicas = 3  # Customize here
        service = {
          type          = "NodePort"
          nodePortHttp  = var.node_port_http
          nodePortHttps = var.node_port_https
        }
        # ... more configuration ...
      }
    })
  ]
}
```

## Comparison

| Feature | External YAML | Inline Terraform |
|---------|---------------|------------------|
| Ease of editing | ✅ Simple YAML syntax | ⚠️ HCL syntax |
| Maintainability | ✅ Single source of truth | ⚠️ Split across files |
| Familiarity | ✅ Same as Helm CLI | ⚠️ Terraform-specific |
| Version control | ✅ Separate file changes | ⚠️ Mixed with infrastructure |
| Migration from scripts | ✅ Copy existing files | ❌ Manual conversion |
| Terraform variables | ⚠️ Limited | ✅ Full access |

**Recommendation:** Use **External YAML Files** for most use cases.

## Advanced: Dynamic Values with Terraform Variables

You can combine both approaches using Terraform's `templatefile()` function:

### Example: Template YAML File

**File:** `modules/argocd/values.yaml.tpl`

```yaml
server:
  replicas: ${replicas}  # Terraform variable
  service:
    type: NodePort
    nodePortHttp: ${node_port}
  extraArgs:
    - --insecure
```

**File:** `modules/argocd/main.tf`

```hcl
resource "helm_release" "argocd" {
  values = [
    templatefile("${path.module}/values.yaml.tpl", {
      replicas  = 3
      node_port = var.node_port_http
    })
  ]
}
```

This approach combines the readability of YAML with the power of Terraform variables.

## Common Customizations

### ArgoCD: Enable HA Mode

**File:** `modules/argocd/values.yaml`

```yaml
server:
  replicas: 3

redis-ha:
  enabled: true

controller:
  replicas: 3
```

### GitLab: Increase Resources

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

### Rancher: Custom TLS

**File:** `modules/rancher/values.yaml`

```yaml
tls: ingress
ingress:
  enabled: true
  tls:
    source: secret
    secretName: tls-rancher-ingress
```

### LocalStack: Enable Pro Features

**File:** `modules/localstack/values.yaml`

```yaml
image:
  repository: localstack/localstack-pro
  tag: "latest"

extraEnvVars:
  - name: LOCALSTACK_API_KEY
    value: "your-api-key"
  - name: SERVICES
    value: "s3,dynamodb,lambda,ecs,eks"
```

## Troubleshooting

### Values Not Applied

1. **Check file path:**
   ```bash
   ls -la terraform/modules/argocd/values.yaml
   ```

2. **Validate YAML syntax:**
   ```bash
   yamllint terraform/modules/argocd/values.yaml
   ```

3. **Check Terraform plan:**
   ```bash
   terraform plan
   # Look for the helm_release changes
   ```

### Override Not Working

If your changes aren't being applied, force a Helm upgrade:

```bash
# Taint the Helm release to force recreation
terraform taint 'module.argocd[0].helm_release.argocd'
terraform apply
```

### Syntax Errors in YAML

Ensure proper YAML indentation:

```yaml
# ❌ Wrong
server:
service:
  type: NodePort

# ✅ Correct
server:
  service:
    type: NodePort
```

## Best Practices

1. **Keep values files in version control** - Track changes over time
2. **Document custom changes** - Add comments in YAML files
3. **Test in dev first** - Try changes in a test cluster
4. **Use separate files for secrets** - Don't commit sensitive data
5. **Validate before applying** - Use `terraform plan` to review changes

## Migration Guide

### From Shell Scripts to Terraform

If you're migrating from the shell script setup:

1. **Copy your existing values files:**
   ```bash
   cp ArgoCD/argocd-values.yaml terraform/modules/argocd/values.yaml
   cp GitLab/gitlab-values.yaml terraform/modules/gitlab/values.yaml
   cp Rancher/rancher-values.yaml terraform/modules/rancher/values.yaml
   cp LocalStack/localstack-values.yaml terraform/modules/localstack/values.yaml
   ```

2. **Verify they're being used:**
   ```bash
   cd terraform
   terraform plan
   # Check that it shows using the values files
   ```

3. **Apply:**
   ```bash
   terraform apply
   ```

Your existing configurations will be preserved!

## Reference Links

- [Helm Values Files](https://helm.sh/docs/chart_template_guide/values_files/)
- [Terraform file() Function](https://www.terraform.io/language/functions/file)
- [Terraform templatefile() Function](https://www.terraform.io/language/functions/templatefile)
- [ArgoCD Helm Chart Values](https://github.com/argoproj/argo-helm/tree/main/charts/argo-cd)
- [GitLab Helm Chart Values](https://docs.gitlab.com/charts/)
- [Rancher Helm Chart Values](https://ranchermanager.docs.rancher.com/pages-for-subheaders/install-upgrade-on-a-kubernetes-cluster)
- [LocalStack Helm Chart Values](https://github.com/localstack/helm-charts)
