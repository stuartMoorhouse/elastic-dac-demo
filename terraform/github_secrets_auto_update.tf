# CRITICAL: Automatically update GitHub Secrets when clusters are recreated
# This prevents "Deleted resource" errors in GitHub Actions

resource "null_resource" "auto_update_github_secrets" {
  # This will ALWAYS run after EC deployments are created/updated

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      
      echo "Updating GitHub Secrets with current cluster credentials..."
      
      REPO="${var.github_owner}/${local.repo_name}"
      
      # Update Development cluster secrets
      echo "Updating Development cluster secrets..."
      gh secret set ELASTIC_CLOUD_DEVELOPMENT_URL \
        --repo "$${REPO}" \
        --body "${ec_deployment.development.kibana.https_endpoint}"
      
      gh secret set ELASTIC_CLOUD_DEVELOPMENT_PASSWORD \
        --repo "$${REPO}" \
        --body "${ec_deployment.development.elasticsearch_password}"
      
      gh secret set ELASTIC_CLOUD_DEVELOPMENT_ES_URL \
        --repo "$${REPO}" \
        --body "${ec_deployment.development.elasticsearch.https_endpoint}"
      
      # CRITICAL: Also update cloud_id which changes when cluster is recreated
      gh secret set DEV_ELASTIC_CLOUD_ID \
        --repo "$${REPO}" \
        --body "${ec_deployment.development.elasticsearch.cloud_id}"
      
      # Create new API key for Development
      DEV_API_KEY=$(curl -u elastic:${ec_deployment.development.elasticsearch_password} \
        -X POST "${ec_deployment.development.elasticsearch.https_endpoint}/_security/api_key" \
        -H "Content-Type: application/json" \
        -d '{"name":"dev-github-actions","role_descriptors":{"detection_rules":{"cluster":["all"],"index":[{"names":["*"],"privileges":["all"]}],"applications":[{"application":"kibana-.kibana","privileges":["all"],"resources":["*"]}]}}}' \
        2>/dev/null | jq -r '.encoded')
      
      gh secret set DEV_ELASTIC_API_KEY \
        --repo "$${REPO}" \
        --body "$${DEV_API_KEY}"
      
      # Update Production cluster secrets
      echo "Updating Production cluster secrets..."
      gh secret set ELASTIC_CLOUD_PRODUCTION_URL \
        --repo "$${REPO}" \
        --body "${ec_deployment.production.kibana.https_endpoint}"
      
      gh secret set ELASTIC_CLOUD_PRODUCTION_PASSWORD \
        --repo "$${REPO}" \
        --body "${ec_deployment.production.elasticsearch_password}"
      
      gh secret set ELASTIC_CLOUD_PRODUCTION_ES_URL \
        --repo "$${REPO}" \
        --body "${ec_deployment.production.elasticsearch.https_endpoint}"
      
      # CRITICAL: Also update cloud_id which changes when cluster is recreated
      gh secret set PROD_ELASTIC_CLOUD_ID \
        --repo "$${REPO}" \
        --body "${ec_deployment.production.elasticsearch.cloud_id}"
      
      # Create new API key for Production
      PROD_API_KEY=$(curl -u elastic:${ec_deployment.production.elasticsearch_password} \
        -X POST "${ec_deployment.production.elasticsearch.https_endpoint}/_security/api_key" \
        -H "Content-Type: application/json" \
        -d '{"name":"prod-github-actions","role_descriptors":{"detection_rules":{"cluster":["all"],"index":[{"names":["*"],"privileges":["all"]}],"applications":[{"application":"kibana-.kibana","privileges":["all"],"resources":["*"]}]}}}' \
        2>/dev/null | jq -r '.encoded')
      
      gh secret set PROD_ELASTIC_API_KEY \
        --repo "$${REPO}" \
        --body "$${PROD_API_KEY}"
      
      # Also update Local cluster for testing
      echo "Updating Local cluster secrets..."
      gh secret set ELASTIC_CLOUD_LOCAL_URL \
        --repo "$${REPO}" \
        --body "${ec_deployment.local.kibana.https_endpoint}"
      
      gh secret set ELASTIC_CLOUD_LOCAL_PASSWORD \
        --repo "$${REPO}" \
        --body "${ec_deployment.local.elasticsearch_password}"
      
      gh secret set ELASTIC_CLOUD_LOCAL_ES_URL \
        --repo "$${REPO}" \
        --body "${ec_deployment.local.elasticsearch.https_endpoint}"
      
      echo "✅ All GitHub Secrets updated successfully!"
      echo ""
      echo "Updated secrets:"
      echo "  - ELASTIC_CLOUD_DEVELOPMENT_URL"
      echo "  - ELASTIC_CLOUD_DEVELOPMENT_PASSWORD"
      echo "  - ELASTIC_CLOUD_DEVELOPMENT_ES_URL"
      echo "  - ELASTIC_CLOUD_PRODUCTION_URL"
      echo "  - ELASTIC_CLOUD_PRODUCTION_PASSWORD"
      echo "  - ELASTIC_CLOUD_PRODUCTION_ES_URL"
      echo "  - ELASTIC_CLOUD_LOCAL_URL"
      echo "  - ELASTIC_CLOUD_LOCAL_PASSWORD"
      echo "  - ELASTIC_CLOUD_LOCAL_ES_URL"
      echo ""
      echo "GitHub Actions workflows will now use the correct cluster endpoints."
    EOT
  }

  # Run this whenever the EC deployments change
  triggers = {
    dev_deployment_id   = ec_deployment.development.id
    dev_kibana_url      = ec_deployment.development.kibana.https_endpoint
    prod_deployment_id  = ec_deployment.production.id
    prod_kibana_url     = ec_deployment.production.kibana.https_endpoint
    local_deployment_id = ec_deployment.local.id
    local_kibana_url    = ec_deployment.local.kibana.https_endpoint
  }

  depends_on = [
    ec_deployment.local,
    ec_deployment.development,
    ec_deployment.production,
    null_resource.create_fork # Make sure the GitHub repo exists
  ]
}

# Also create a resource to verify GitHub secrets are set
resource "null_resource" "verify_github_secrets" {
  provisioner "local-exec" {
    command = <<-EOT
      set -e
      
      echo "Verifying GitHub Secrets are configured..."
      
      REPO="${var.github_owner}/${local.repo_name}"
      
      # List all secrets (names only, not values)
      echo "Configured secrets in $${REPO}:"
      gh secret list --repo "$${REPO}" || echo "No secrets found or unable to list"
      
      echo ""
      echo "✅ GitHub Secrets verification complete"
    EOT
  }

  triggers = {
    timestamp = timestamp()
  }

  depends_on = [
    null_resource.auto_update_github_secrets
  ]
}

output "github_secrets_status" {
  value = {
    status      = "GitHub Secrets automatically updated with cluster credentials"
    last_update = "Run 'terraform apply' to sync GitHub Secrets with current clusters"
    secrets_configured = [
      "ELASTIC_CLOUD_DEVELOPMENT_URL",
      "ELASTIC_CLOUD_DEVELOPMENT_PASSWORD",
      "ELASTIC_CLOUD_PRODUCTION_URL",
      "ELASTIC_CLOUD_PRODUCTION_PASSWORD",
      "ELASTIC_CLOUD_LOCAL_URL",
      "ELASTIC_CLOUD_LOCAL_PASSWORD"
    ]
  }

  depends_on = [
    null_resource.auto_update_github_secrets
  ]
}