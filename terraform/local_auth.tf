# Configure authentication for detection-rules repository to access local Elastic cluster

# Generate API key for the local Elastic cluster
resource "null_resource" "generate_elastic_api_key" {
  depends_on = [
    ec_deployment.local,
    null_resource.clone_repository
  ]

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      
      echo "Generating API key for detection-rules..."
      
      # Get the Elasticsearch endpoint and credentials
      ES_ENDPOINT="${ec_deployment.local.elasticsearch.https_endpoint}"
      ES_USERNAME="${ec_deployment.local.elasticsearch_username}"
      ES_PASSWORD="${ec_deployment.local.elasticsearch_password}"
      
      # Generate API key using curl
      API_KEY_RESPONSE=$(curl -s -X POST \
        -u "$${ES_USERNAME}:$${ES_PASSWORD}" \
        "$${ES_ENDPOINT}/_security/api_key" \
        -H "Content-Type: application/json" \
        -d '{
          "name": "detection-rules-api-key",
          "role_descriptors": {
            "detection_rules_role": {
              "cluster": ["all"],
              "index": [
                {
                  "names": ["*"],
                  "privileges": ["all"]
                }
              ],
              "applications": [
                {
                  "application": "kibana-.kibana",
                  "privileges": ["all"],
                  "resources": ["*"]
                }
              ]
            }
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
      
      # Store the API key in a temporary file for the next resource to use
      echo "$${ENCODED_API_KEY}" > /tmp/elastic_api_key.txt
      
      echo "API key generated successfully"
    EOT
  }

  triggers = {
    deployment_id = ec_deployment.local.id
    repo_name     = local.repo_name
  }
}

# Write .detection-rules-cfg.json configuration file
resource "null_resource" "write_detection_rules_config" {
  depends_on = [
    null_resource.generate_elastic_api_key,
    null_resource.clone_repository  # Add dependency on clone to ensure repo exists
  ]

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      
      REPO_DIR="../../${local.repo_name}"
      CONFIG_FILE="$${REPO_DIR}/.detection-rules-cfg.json"
      
      echo "Writing .detection-rules-cfg.json configuration file..."
      
      # First, check if the repository directory exists
      if [ ! -d "$${REPO_DIR}" ]; then
        echo "Error: Repository directory $${REPO_DIR} not found"
        echo "Waiting for repository to be cloned..."
        sleep 5
      fi
      
      # Read the API key from the temporary file (or regenerate if needed)
      if [ -f /tmp/elastic_api_key.txt ]; then
        API_KEY=$(cat /tmp/elastic_api_key.txt)
      else
        echo "Regenerating API key..."
        # Regenerate the API key if the temp file is missing
        ES_ENDPOINT="${ec_deployment.local.elasticsearch.https_endpoint}"
        ES_USERNAME="${ec_deployment.local.elasticsearch_username}"
        ES_PASSWORD="${ec_deployment.local.elasticsearch_password}"
        
        API_KEY_RESPONSE=$(curl -s -X POST \
          -u "$${ES_USERNAME}:$${ES_PASSWORD}" \
          "$${ES_ENDPOINT}/_security/api_key" \
          -H "Content-Type: application/json" \
          -d '{
            "name": "detection-rules-api-key-regenerated",
            "role_descriptors": {
              "detection_rules_role": {
                "cluster": ["all"],
                "index": [{"names": ["*"], "privileges": ["all"]}],
                "applications": [{"application": "kibana-.kibana", "privileges": ["all"], "resources": ["*"]}]
              }
            }
          }')
        
        API_KEY_ID=$(echo "$${API_KEY_RESPONSE}" | jq -r '.id')
        API_KEY_VALUE=$(echo "$${API_KEY_RESPONSE}" | jq -r '.api_key')
        API_KEY=$(printf "%s:%s" "$${API_KEY_ID}" "$${API_KEY_VALUE}" | base64 | tr -d '\n')
      fi
      
      # Always create/update the configuration file
      cat > "$${CONFIG_FILE}" << CONFIG
{
  "cloud_id": "${ec_deployment.local.elasticsearch.cloud_id}",
  "api_key": "$${API_KEY}"
}
CONFIG
      
      echo ".detection-rules-cfg.json created successfully at $${CONFIG_FILE}"
      
      # Also store in elastic/credentials for reference
      mkdir -p ./elastic/credentials
      cat > ./elastic/credentials/local-cluster.json << CREDS
{
  "cloud_id": "${ec_deployment.local.elasticsearch.cloud_id}",
  "api_key": "$${API_KEY}",
  "cluster_url": "${ec_deployment.local.elasticsearch.https_endpoint}",
  "kibana_url": "${ec_deployment.local.kibana.https_endpoint}",
  "environment": "local",
  "created_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
CREDS
      
      # Clean up temporary file
      rm -f /tmp/elastic_api_key.txt
    EOT
  }

  triggers = {
    deployment_id = ec_deployment.local.id
    repo_name     = local.repo_name
    # Add a trigger that changes when the clone_repository resource is recreated
    clone_timestamp = null_resource.clone_repository.id
  }
}

# Output the configuration status
output "detection_rules_auth_configured" {
  value       = true
  description = "Detection rules authentication has been configured"
  depends_on = [
    null_resource.write_detection_rules_config
  ]
}

output "detection_rules_config_location" {
  value       = "../../${local.repo_name}/.detection-rules-cfg.json"
  description = "Location of the detection-rules configuration file"
  depends_on  = [null_resource.write_detection_rules_config]
}