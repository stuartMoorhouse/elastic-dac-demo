locals {
  environments = {
    production = {
      name = var.deployment_name_production
      tags = {
        environment = "production"
        purpose     = "dac-demo"
        managed_by  = "terraform"
      }
    }
    development = {
      name = var.deployment_name_development
      tags = {
        environment = "development"
        purpose     = "dac-demo"
        managed_by  = "terraform"
      }
    }
  }
}

resource "ec_deployment" "this" {
  for_each = local.environments

  name                   = each.value.name
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

  tags = each.value.tags
}