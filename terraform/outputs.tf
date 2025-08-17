# Production deployment outputs
output "production_deployment_id" {
  value       = ec_deployment.production.id
  description = "Production deployment ID"
}

output "production_elasticsearch_endpoint" {
  value       = ec_deployment.production.elasticsearch.https_endpoint
  description = "Production Elasticsearch endpoint"
}

output "production_kibana_endpoint" {
  value       = ec_deployment.production.kibana.https_endpoint
  description = "Production Kibana endpoint"
}

output "production_elasticsearch_username" {
  value       = ec_deployment.production.elasticsearch_username
  description = "Production Elasticsearch username"
}

output "production_elasticsearch_password" {
  value       = ec_deployment.production.elasticsearch_password
  sensitive   = true
  description = "Production Elasticsearch password"
}

# Development deployment outputs
output "development_deployment_id" {
  value       = ec_deployment.development.id
  description = "Development deployment ID"
}

output "development_elasticsearch_endpoint" {
  value       = ec_deployment.development.elasticsearch.https_endpoint
  description = "Development Elasticsearch endpoint"
}

output "development_kibana_endpoint" {
  value       = ec_deployment.development.kibana.https_endpoint
  description = "Development Kibana endpoint"
}

output "development_elasticsearch_username" {
  value       = ec_deployment.development.elasticsearch_username
  description = "Development Elasticsearch username"
}

output "development_elasticsearch_password" {
  value       = ec_deployment.development.elasticsearch_password
  sensitive   = true
  description = "Development Elasticsearch password"
}

output "github_repository_name" {
  value       = local.repo_name
  description = "Name of the forked repository"
  depends_on  = [null_resource.create_fork]
}

output "github_repository_location" {
  value       = "../../${local.repo_name}"
  description = "Location of the cloned detection-rules repository"
  depends_on  = [null_resource.clone_repository]
}

output "github_repository_url" {
  value       = "https://github.com/$${data.external.github_user.result.login}/${local.repo_name}"
  description = "GitHub URL of the forked repository"
  depends_on  = [null_resource.create_fork]
}

# Local deployment outputs
output "local_deployment_id" {
  value       = ec_deployment.local.id
  description = "Local deployment ID"
}

output "local_elasticsearch_endpoint" {
  value       = ec_deployment.local.elasticsearch.https_endpoint
  description = "Local Elasticsearch endpoint"
}

output "local_kibana_endpoint" {
  value       = ec_deployment.local.kibana.https_endpoint
  description = "Local Kibana endpoint"
}

output "local_elasticsearch_username" {
  value       = ec_deployment.local.elasticsearch_username
  description = "Local Elasticsearch username"
}

output "local_elasticsearch_password" {
  value       = ec_deployment.local.elasticsearch_password
  sensitive   = true
  description = "Local Elasticsearch password"
}