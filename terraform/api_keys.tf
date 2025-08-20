# Configure API keys for GitHub Actions to access Elastic clusters
# This creates roles with minimal permissions and API keys for detection rules management

locals {
  # Define the minimal role for detection rules management
  detection_rules_role = {
    cluster = [
      "monitor",                # View cluster metadata
      "manage_index_templates", # Manage index templates for .siem-signals-*
      "manage_transform"        # Manage transforms if needed
    ]
    indices = [
      {
        names = [
          ".siem-signals-*",   # Detection alerts index
          ".lists-*",          # Exception lists
          ".items-*",          # Exception list items
          "logs-*",            # Log indices
          "filebeat-*",        # Filebeat indices
          "packetbeat-*",      # Packetbeat indices
          "winlogbeat-*",      # Winlogbeat indices
          "auditbeat-*",       # Auditbeat indices
          "endgame-*",         # Endgame indices
          "metrics-*",         # Metrics indices
          ".alerts-security.*" # Security alerts
        ]
        privileges = [
          "read",                # Read documents
          "view_index_metadata", # View index metadata
          "write",               # Write documents (for .siem-signals-*)
          "create_index",        # Create indices (for .siem-signals-*)
          "delete_index",        # Delete indices (for cleanup)
          "manage"               # Manage indices
        ]
      }
    ]
    applications = [
      {
        application = "kibana-.kibana"
        privileges = [
          "feature_siem.all",         # Full access to Security app
          "feature_actions.all",      # Manage actions
          "feature_stackAlerts.all",  # Manage stack alerts
          "feature_rulesSettings.all" # Manage rules settings
        ]
        resources = ["*"]
      }
    ]
  }
}

# Create role and API key for Development cluster
resource "null_resource" "create_dev_api_key" {
  depends_on = [
    ec_deployment.development,
    null_resource.clone_repository
  ]

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      
      echo "Creating API key for Development Elastic cluster..."
      
      # Get the Elasticsearch endpoint and credentials
      ES_ENDPOINT="${ec_deployment.development.elasticsearch.https_endpoint}"
      ES_USERNAME="${ec_deployment.development.elasticsearch_username}"
      ES_PASSWORD="${ec_deployment.development.elasticsearch_password}"
      
      echo "Creating detection-rules-manager role in Development cluster..."
      
      # Create the role
      curl -s -X PUT \
        -u "$${ES_USERNAME}:$${ES_PASSWORD}" \
        "$${ES_ENDPOINT}/_security/role/detection_rules_manager" \
        -H "Content-Type: application/json" \
        -d '${jsonencode(local.detection_rules_role)}' || echo "Role might already exist"
      
      echo "Generating API key for GitHub Actions (Development)..."
      
      # Generate API key with the role
      API_KEY_RESPONSE=$(curl -s -X POST \
        -u "$${ES_USERNAME}:$${ES_PASSWORD}" \
        "$${ES_ENDPOINT}/_security/api_key" \
        -H "Content-Type: application/json" \
        -d '{
          "name": "github-actions-dev-api-key",
          "role_descriptors": {
            "detection_rules_manager": ${jsonencode(local.detection_rules_role)}
          },
          "metadata": {
            "purpose": "GitHub Actions CI/CD for Development",
            "created_by": "Terraform",
            "environment": "development"
          }
        }')
      
      # Extract the API key
      API_KEY_ID=$(echo "$${API_KEY_RESPONSE}" | jq -r '.id')
      API_KEY_VALUE=$(echo "$${API_KEY_RESPONSE}" | jq -r '.api_key')
      
      if [ -z "$${API_KEY_ID}" ] || [ -z "$${API_KEY_VALUE}" ] || [ "$${API_KEY_ID}" = "null" ] || [ "$${API_KEY_VALUE}" = "null" ]; then
        echo "Failed to generate API key. Response: $${API_KEY_RESPONSE}"
        exit 1
      fi
      
      # Combine ID and key in the format Elastic expects
      # Use printf to avoid newline issues and ensure proper encoding
      ENCODED_API_KEY=$(printf "%s:%s" "$${API_KEY_ID}" "$${API_KEY_VALUE}" | base64 | tr -d '\n')
      
      # Store the API key and Cloud ID in a local file (not in source control)
      mkdir -p ./elastic/credentials
      cat > ./elastic/credentials/dev-cluster.json << CREDS
{
  "cloud_id": "${ec_deployment.development.elasticsearch.cloud_id}",
  "api_key": "$${ENCODED_API_KEY}",
  "cluster_url": "${ec_deployment.development.elasticsearch.https_endpoint}",
  "kibana_url": "${ec_deployment.development.kibana.https_endpoint}",
  "environment": "development",
  "created_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
CREDS
      
      echo "Development API key generated and stored in ./elastic/credentials/dev-cluster.json"
      
      # Store in temp file for GitHub secret creation
      echo "$${ENCODED_API_KEY}" > /tmp/dev_elastic_api_key.txt
      echo "${ec_deployment.development.elasticsearch.cloud_id}" > /tmp/dev_elastic_cloud_id.txt
    EOT
  }

  triggers = {
    deployment_id = ec_deployment.development.id
    role_config   = jsonencode(local.detection_rules_role)
  }
}

# Create role and API key for Production cluster
resource "null_resource" "create_prod_api_key" {
  depends_on = [
    ec_deployment.production,
    null_resource.clone_repository
  ]

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      
      echo "Creating API key for Production Elastic cluster..."
      
      # Get the Elasticsearch endpoint and credentials
      ES_ENDPOINT="${ec_deployment.production.elasticsearch.https_endpoint}"
      ES_USERNAME="${ec_deployment.production.elasticsearch_username}"
      ES_PASSWORD="${ec_deployment.production.elasticsearch_password}"
      
      echo "Creating detection-rules-manager role in Production cluster..."
      
      # Create the role
      curl -s -X PUT \
        -u "$${ES_USERNAME}:$${ES_PASSWORD}" \
        "$${ES_ENDPOINT}/_security/role/detection_rules_manager" \
        -H "Content-Type: application/json" \
        -d '${jsonencode(local.detection_rules_role)}' || echo "Role might already exist"
      
      echo "Generating API key for GitHub Actions (Production)..."
      
      # Generate API key with the role
      API_KEY_RESPONSE=$(curl -s -X POST \
        -u "$${ES_USERNAME}:$${ES_PASSWORD}" \
        "$${ES_ENDPOINT}/_security/api_key" \
        -H "Content-Type: application/json" \
        -d '{
          "name": "github-actions-prod-api-key",
          "role_descriptors": {
            "detection_rules_manager": ${jsonencode(local.detection_rules_role)}
          },
          "metadata": {
            "purpose": "GitHub Actions CI/CD for Production",
            "created_by": "Terraform",
            "environment": "production"
          }
        }')
      
      # Extract the API key
      API_KEY_ID=$(echo "$${API_KEY_RESPONSE}" | jq -r '.id')
      API_KEY_VALUE=$(echo "$${API_KEY_RESPONSE}" | jq -r '.api_key')
      
      if [ -z "$${API_KEY_ID}" ] || [ -z "$${API_KEY_VALUE}" ] || [ "$${API_KEY_ID}" = "null" ] || [ "$${API_KEY_VALUE}" = "null" ]; then
        echo "Failed to generate API key. Response: $${API_KEY_RESPONSE}"
        exit 1
      fi
      
      # Combine ID and key in the format Elastic expects
      # Use printf to avoid newline issues and ensure proper encoding
      ENCODED_API_KEY=$(printf "%s:%s" "$${API_KEY_ID}" "$${API_KEY_VALUE}" | base64 | tr -d '\n')
      
      # Store the API key and Cloud ID in a local file (not in source control)
      mkdir -p ./elastic/credentials
      cat > ./elastic/credentials/prod-cluster.json << CREDS
{
  "cloud_id": "${ec_deployment.production.elasticsearch.cloud_id}",
  "api_key": "$${ENCODED_API_KEY}",
  "cluster_url": "${ec_deployment.production.elasticsearch.https_endpoint}",
  "kibana_url": "${ec_deployment.production.kibana.https_endpoint}",
  "environment": "production",
  "created_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
CREDS
      
      echo "Production API key generated and stored in ./elastic/credentials/prod-cluster.json"
      
      # Store in temp file for GitHub secret creation
      echo "$${ENCODED_API_KEY}" > /tmp/prod_elastic_api_key.txt
      echo "${ec_deployment.production.elasticsearch.cloud_id}" > /tmp/prod_elastic_cloud_id.txt
    EOT
  }

  triggers = {
    deployment_id = ec_deployment.production.id
    role_config   = jsonencode(local.detection_rules_role)
  }
}

# Update GitHub Actions secrets with API keys and Cloud IDs
resource "null_resource" "update_github_secrets" {
  depends_on = [
    null_resource.create_dev_api_key,
    null_resource.create_prod_api_key,
    data.github_repository.detection_rules,
    github_branch.dev,             # Ensure dev branch exists before setting secrets
    null_resource.clone_repository # Ensure repository is fully set up
  ]

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      
      echo "Updating GitHub Actions secrets with API keys and Cloud IDs..."
      
      # Read the API keys and Cloud IDs from temp files
      if [ -f /tmp/dev_elastic_api_key.txt ] && [ -f /tmp/dev_elastic_cloud_id.txt ]; then
        DEV_API_KEY=$(cat /tmp/dev_elastic_api_key.txt)
        DEV_CLOUD_ID=$(cat /tmp/dev_elastic_cloud_id.txt)
      else
        echo "Error: Development API key or Cloud ID file not found"
        exit 1
      fi
      
      if [ -f /tmp/prod_elastic_api_key.txt ] && [ -f /tmp/prod_elastic_cloud_id.txt ]; then
        PROD_API_KEY=$(cat /tmp/prod_elastic_api_key.txt)
        PROD_CLOUD_ID=$(cat /tmp/prod_elastic_cloud_id.txt)
      else
        echo "Error: Production API key or Cloud ID file not found"
        exit 1
      fi
      
      GITHUB_USER="${var.github_owner}"
      REPO_NAME="${local.repo_name}"
      
      # Create or update GitHub secrets for Development
      echo "Setting Development secrets..."
      gh secret set DEV_ELASTIC_CLOUD_ID --body "$${DEV_CLOUD_ID}" --repo "$${GITHUB_USER}/$${REPO_NAME}"
      gh secret set DEV_ELASTIC_API_KEY --body "$${DEV_API_KEY}" --repo "$${GITHUB_USER}/$${REPO_NAME}"
      
      # Create or update GitHub secrets for Production
      echo "Setting Production secrets..."
      gh secret set PROD_ELASTIC_CLOUD_ID --body "$${PROD_CLOUD_ID}" --repo "$${GITHUB_USER}/$${REPO_NAME}"
      gh secret set PROD_ELASTIC_API_KEY --body "$${PROD_API_KEY}" --repo "$${GITHUB_USER}/$${REPO_NAME}"
      
      # Set GitHub Personal Access Token for auto-PR creation
      echo "Setting GitHub PAT for auto-PR creation..."
      gh secret set GH_PAT --body "${var.github_token}" --repo "$${GITHUB_USER}/$${REPO_NAME}"
      
      # Set Detection Team Lead PAT for PR approvals
      echo "Setting Detection Team Lead PAT for PR approvals..."
      gh secret set TEAM_LEAD_PAT --body "${var.detection_team_lead_token}" --repo "$${GITHUB_USER}/$${REPO_NAME}"
      
      # Clean up temp files
      rm -f /tmp/dev_elastic_api_key.txt /tmp/dev_elastic_cloud_id.txt
      rm -f /tmp/prod_elastic_api_key.txt /tmp/prod_elastic_cloud_id.txt
      
      echo "GitHub Actions secrets updated successfully (including GH_PAT for auto-PR)"
    EOT
  }

  triggers = {
    dev_deployment_id  = ec_deployment.development.id
    prod_deployment_id = ec_deployment.production.id
    repo_name          = local.repo_name
  }
}

# Output to confirm API key creation
output "elastic_api_keys_configured" {
  value       = true
  description = "Elastic API keys have been configured for GitHub Actions"
  depends_on = [
    null_resource.update_github_secrets
  ]
}

output "elastic_credentials_location" {
  value       = "./elastic/credentials/"
  description = "Location of stored Elastic credentials (not in source control)"
  depends_on = [
    null_resource.create_dev_api_key,
    null_resource.create_prod_api_key
  ]
}