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
      ENCODED_API_KEY=$(echo -n "$${API_KEY_ID}:$${API_KEY_VALUE}" | base64)
      
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
  depends_on = [null_resource.generate_elastic_api_key]

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      
      REPO_DIR="../../${local.repo_name}"
      CONFIG_FILE="$${REPO_DIR}/.detection-rules-cfg.json"
      
      echo "Writing .detection-rules-cfg.json configuration file..."
      
      # Read the API key from the temporary file
      if [ -f /tmp/elastic_api_key.txt ]; then
        API_KEY=$(cat /tmp/elastic_api_key.txt)
      else
        echo "Error: API key file not found"
        exit 1
      fi
      
      # Create the configuration file
      cat > "$${CONFIG_FILE}" << CONFIG
{
  "cloud_id": "${ec_deployment.local.elasticsearch.cloud_id}",
  "api_key": "$${API_KEY}"
}
CONFIG
      
      echo ".detection-rules-cfg.json created successfully"
      
      # Clean up temporary file
      rm -f /tmp/elastic_api_key.txt
    EOT
  }

  triggers = {
    deployment_id = ec_deployment.local.id
    repo_name     = local.repo_name
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