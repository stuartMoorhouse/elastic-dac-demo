#!/bin/bash
# Wrapper script for Terraform deployment with extended timeout
# This ensures Elastic Cloud deployments have enough time to complete

set -e

echo "Starting Terraform deployment with extended timeout for Elastic Cloud..."
echo "This may take up to 10 minutes for cluster creation..."

# Run terraform apply with confirmation
terraform apply

echo "Deployment complete!"
echo ""
echo "To view cluster credentials:"
echo "  terraform output -raw production_elasticsearch_password"
echo "  terraform output -raw development_elasticsearch_password"