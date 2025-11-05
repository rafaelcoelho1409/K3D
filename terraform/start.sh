#!/bin/bash
# ... your existing cleanup code ...
echo "Deploying infrastructure..."
terraform init
terraform apply -target=module.k3d_cluster -auto-approve
terraform apply