output "deployments" {
  value = {
    for k, v in ec_deployment.this : k => {
      id                     = v.id
      elasticsearch_endpoint = v.elasticsearch.https_endpoint
      kibana_endpoint        = v.kibana.https_endpoint
      elasticsearch_username = v.elasticsearch_username
    }
  }
  description = "Deployment details for all environments"
}

output "elasticsearch_passwords" {
  value = {
    for k, v in ec_deployment.this : k => v.elasticsearch_password
  }
  sensitive   = true
  description = "Elasticsearch passwords for all environments"
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