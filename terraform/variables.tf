variable "region" {
  description = "Elastic Cloud region for deployments"
  type        = string
  default     = "gcp-europe-north1"

  validation {
    condition     = can(regex("^(aws|gcp|azure)-[a-z0-9-]+$", var.region))
    error_message = "Region must be a valid Elastic Cloud region (e.g., gcp-europe-north1, aws-us-east-1)."
  }
}

variable "elastic_version" {
  description = "Elasticsearch version to deploy"
  type        = string
  default     = "9.1.2"

  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+$", var.elastic_version))
    error_message = "Elastic version must be in semantic version format (e.g., 9.1.2)."
  }
}

variable "deployment_template_id" {
  description = "Deployment template ID for Elastic Cloud"
  type        = string
  default     = "gcp-storage-optimized"
}

variable "deployment_name_production" {
  description = "Name for the production Elastic Cloud deployment"
  type        = string
  default     = "elastic-cloud-production"
}

variable "deployment_name_development" {
  description = "Name for the development Elastic Cloud deployment"
  type        = string
  default     = "elastic-cloud-development"
}

variable "deployment_name_local" {
  description = "Name for the local Elastic Cloud deployment"
  type        = string
  default     = "elastic-cloud-local"
}

variable "elasticsearch_size" {
  description = "Size of Elasticsearch instances (in GB RAM)"
  type        = string
  default     = "8g"

  validation {
    condition     = can(regex("^[0-9]+g$", var.elasticsearch_size))
    error_message = "Elasticsearch size must be specified in GB (e.g., 8g, 16g)."
  }
}

variable "elasticsearch_zone_count" {
  description = "Number of availability zones for Elasticsearch"
  type        = number
  default     = 1

  validation {
    condition     = var.elasticsearch_zone_count >= 1 && var.elasticsearch_zone_count <= 3
    error_message = "Zone count must be between 1 and 3."
  }
}

variable "kibana_size" {
  description = "Size of Kibana instances (in GB RAM)"
  type        = string
  default     = "2g"
}

variable "kibana_zone_count" {
  description = "Number of availability zones for Kibana"
  type        = number
  default     = 1
}

variable "integrations_server_size" {
  description = "Size of Integrations Server instances (in GB RAM)"
  type        = string
  default     = "1g"
}

variable "integrations_server_zone_count" {
  description = "Number of availability zones for Integrations Server"
  type        = number
  default     = 1
}

variable "repo_name_prefix" {
  description = "Prefix for the forked detection-rules repository"
  type        = string
  default     = "dac-demo"
}

variable "ec_api_key" {
  description = "Elastic Cloud API key for managing deployments"
  type        = string
  sensitive   = true
}

variable "github_token" {
  description = "GitHub Personal Access Token with repo and workflow scopes"
  type        = string
  sensitive   = true
}