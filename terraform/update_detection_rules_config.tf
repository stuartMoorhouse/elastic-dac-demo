# CRITICAL: Always update detection-rules configuration with current cluster credentials
# This prevents the "Deleted resource" error when clusters are recreated

resource "null_resource" "always_update_detection_rules_config" {
  # This will ALWAYS run after EC deployments are created/updated

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      
      echo "Updating detection-rules configuration with current cluster credentials..."
      
      REPO_DIR="../../dac-demo-detection-rules"
      CONFIG_FILE="$${REPO_DIR}/.detection-rules-cfg.json"
      
      if [ ! -d "$${REPO_DIR}" ]; then
        echo "ERROR: Detection rules repository not found at $${REPO_DIR}"
        echo "The repository should be cloned by Terraform but may have failed due to GitHub token issues"
        exit 1
      fi
      
      # Get the current Local cluster credentials
      LOCAL_KIBANA_URL="${ec_deployment.local.kibana.https_endpoint}"
      LOCAL_ES_URL="${ec_deployment.local.elasticsearch.https_endpoint}"
      LOCAL_PASSWORD="${ec_deployment.local.elasticsearch_password}"

      # The detection-rules CLI only supports api_key auth for Kibana (kibana_username/password are ignored),
      # so mint a fresh Elasticsearch API key here and write it into the config file.
      API_KEY_RESPONSE=$(curl -sf -X POST \
        -u "elastic:$${LOCAL_PASSWORD}" \
        -H "Content-Type: application/json" \
        "$${LOCAL_ES_URL}/_security/api_key" \
        -d '{"name":"detection-rules-cli","metadata":{"created_by":"terraform","purpose":"detection-rules CLI auth"}}')

      LOCAL_ENCODED_API_KEY=$(printf '%s' "$${API_KEY_RESPONSE}" | jq -r '.encoded')

      if [ -z "$${LOCAL_ENCODED_API_KEY}" ] || [ "$${LOCAL_ENCODED_API_KEY}" = "null" ]; then
        echo "ERROR: Failed to generate API key for detection-rules CLI. Response: $${API_KEY_RESPONSE}"
        exit 1
      fi

      # Create the configuration file with the minted API key
      cat > "$${CONFIG_FILE}" << EOF
{
  "custom_rules_dir": "dac-demo",
  "kibana_url": "$${LOCAL_KIBANA_URL}",
  "elasticsearch_url": "$${LOCAL_ES_URL}",
  "api_key": "$${LOCAL_ENCODED_API_KEY}"
}
EOF
      
      echo "✅ Detection rules configuration updated with current Local cluster credentials"
      echo "   Kibana URL: $${LOCAL_KIBANA_URL}"
      
      # Also create environment variables file for manual use
      cat > "$${REPO_DIR}/.env" << EOF
# Elastic Cloud credentials for Local cluster
export KIBANA_URL="$${LOCAL_KIBANA_URL}"
export ELASTICSEARCH_URL="$${LOCAL_ES_URL}"
export KIBANA_USERNAME="elastic"
export KIBANA_PASSWORD="$${LOCAL_PASSWORD}"

# Development cluster
export DEV_KIBANA_URL="${ec_deployment.development.kibana.https_endpoint}"
export DEV_ES_URL="${ec_deployment.development.elasticsearch.https_endpoint}"
export DEV_PASSWORD="${ec_deployment.development.elasticsearch_password}"

# Production cluster
export PROD_KIBANA_URL="${ec_deployment.production.kibana.https_endpoint}"
export PROD_ES_URL="${ec_deployment.production.elasticsearch.https_endpoint}"
export PROD_PASSWORD="${ec_deployment.production.elasticsearch_password}"
EOF
      
      echo "✅ Also created .env file with all cluster credentials for manual use"
    EOT
  }

  # Run this whenever the EC deployments change
  triggers = {
    local_deployment_id = ec_deployment.local.id
    dev_deployment_id   = ec_deployment.development.id
    prod_deployment_id  = ec_deployment.production.id
    # Force update every time
    timestamp = timestamp()
  }

  depends_on = [
    ec_deployment.local,
    ec_deployment.development,
    ec_deployment.production
  ]
}

# Also create a resource to check and recreate the clone if missing
resource "null_resource" "ensure_clone_exists" {
  depends_on = [
    null_resource.clone_repository,
    null_resource.setup_dac_demo_rules
  ]

  provisioner "local-exec" {
    command = <<-EOT
      set -e

      REPO_NAME="dac-demo-detection-rules"
      TARGET_DIR="../../$${REPO_NAME}"
      GITHUB_USER="${var.github_owner}"
      GITHUB_TOKEN="${var.github_token}"

      if [ ! -d "$${TARGET_DIR}" ]; then
        echo "⚠️  Repository directory missing, cloning again..."

        # Retry clone with linear backoff to handle GitHub eventual-consistency after fork creation.
        # Use authenticated URL so private repos and rate-limited clones still succeed.
        CLONE_OK=""
        for SLEEP in 0 5 10 20 30; do
          if [ "$${SLEEP}" -gt 0 ]; then
            echo "Clone failed, retrying in $${SLEEP}s..."
            sleep "$${SLEEP}"
          fi
          if git clone "https://$${GITHUB_TOKEN}@github.com/$${GITHUB_USER}/$${REPO_NAME}.git" "$${TARGET_DIR}"; then
            CLONE_OK=1
            break
          fi
        done
        if [ -z "$${CLONE_OK}" ]; then
          echo "ERROR: Failed to clone repository after multiple attempts"
          echo "Please check that https://github.com/$${GITHUB_USER}/$${REPO_NAME} exists and the token has access"
          exit 1
        fi

        cd "$${TARGET_DIR}"

        # Strip the token from the stored remote URL so it doesn't leak into the working copy.
        git remote set-url origin "https://github.com/$${GITHUB_USER}/$${REPO_NAME}.git"

        # Set up Python environment
        echo "Setting up Python virtual environment..."
        /opt/homebrew/bin/python3.12 -m venv env
        ./env/bin/pip install --upgrade pip
        ./env/bin/pip install -e ".[dev]"
        ./env/bin/pip install lib/kql lib/kibana

        echo "✅ Repository cloned and environment set up"
      else
        echo "✅ Repository exists at $${TARGET_DIR}"
      fi
    EOT
  }

  triggers = {
    # Check on every apply
    timestamp = timestamp()
  }
}

output "detection_rules_setup_status" {
  value = {
    config_update         = "Run 'terraform apply' to update detection-rules config with current cluster credentials"
    manual_export_command = "cd dac-demo-detection-rules && source env/bin/activate && python -m detection_rules kibana --space default export-rules --directory dac-demo/rules/ --rule-name 'C2 Beaconing Activity Detection'"
  }

  depends_on = [
    null_resource.always_update_detection_rules_config,
    null_resource.ensure_clone_exists
  ]
}