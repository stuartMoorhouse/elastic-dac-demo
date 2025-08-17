# Elastic Cloud Deployments for Detection as Code Demo
# Creates three environments: Local, Development, and Production

# Local Elastic Cloud Deployment for initial development
resource "ec_deployment" "local" {
  name                   = var.deployment_name_local
  region                 = var.region
  version                = var.elastic_version
  deployment_template_id = var.deployment_template_id

  elasticsearch = {
    hot = {
      size        = var.elasticsearch_size
      zone_count  = var.elasticsearch_zone_count
      autoscaling = {}
    }
  }

  kibana = {
    size       = var.kibana_size
    zone_count = var.kibana_zone_count
  }

  integrations_server = {
    size       = var.integrations_server_size
    zone_count = var.integrations_server_zone_count
  }

  tags = {
    environment = "local"
    purpose     = "dac-demo"
    managed_by  = "terraform"
  }
}

# Development Elastic Cloud Deployment
resource "ec_deployment" "development" {
  name                   = var.deployment_name_development
  region                 = var.region
  version                = var.elastic_version
  deployment_template_id = var.deployment_template_id

  elasticsearch = {
    hot = {
      size        = var.elasticsearch_size
      zone_count  = var.elasticsearch_zone_count
      autoscaling = {}
    }
  }

  kibana = {
    size       = var.kibana_size
    zone_count = var.kibana_zone_count
  }

  integrations_server = {
    size       = var.integrations_server_size
    zone_count = var.integrations_server_zone_count
  }

  tags = {
    environment = "development"
    purpose     = "dac-demo"
    managed_by  = "terraform"
  }
}

# Production Elastic Cloud Deployment
resource "ec_deployment" "production" {
  name                   = var.deployment_name_production
  region                 = var.region
  version                = var.elastic_version
  deployment_template_id = var.deployment_template_id

  elasticsearch = {
    hot = {
      size        = var.elasticsearch_size
      zone_count  = var.elasticsearch_zone_count
      autoscaling = {}
    }
  }

  kibana = {
    size       = var.kibana_size
    zone_count = var.kibana_zone_count
  }

  integrations_server = {
    size       = var.integrations_server_size
    zone_count = var.integrations_server_zone_count
  }

  tags = {
    environment = "production"
    purpose     = "dac-demo"
    managed_by  = "terraform"
  }
}