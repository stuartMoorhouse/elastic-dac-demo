terraform {
  required_version = ">= 1.0"

  required_providers {
    ec = {
      source  = "elastic/ec"
      version = "~> 0.10.0"
    }
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
    external = {
      source  = "hashicorp/external"
      version = "~> 2.3"
    }
  }
}

provider "ec" {}

provider "github" {}