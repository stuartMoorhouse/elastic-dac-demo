# Branch protection rules for Detection as Code repository

# Data source to get the repository
data "github_repository" "detection_rules" {
  name = "${var.repo_name_prefix}-detection-rules"
}

# Create dev branch
resource "github_branch" "dev" {
  repository = data.github_repository.detection_rules.name
  branch     = "dev"
  source_branch = "main"
}

# Main branch protection - Production
resource "github_branch_protection" "main" {
  repository_id = data.github_repository.detection_rules.node_id
  pattern       = "main"

  # Require pull request reviews
  required_pull_request_reviews {
    dismiss_stale_reviews           = true
    required_approving_review_count = 1
    require_code_owner_reviews      = false
    require_last_push_approval      = false
  }

  # Require status checks
  required_status_checks {
    strict   = true
    contexts = ["Lint Detection Rules", "Rule Format Validation"]
  }

  # Enforce for admins
  enforce_admins = true

  # Block direct pushes
  allows_deletions    = false
  allows_force_pushes = false
}

# Dev branch protection - Development
resource "github_branch_protection" "dev" {
  repository_id = data.github_repository.detection_rules.node_id
  pattern       = "dev"

  # Minimal status checks for dev
  required_status_checks {
    strict   = false
    contexts = ["Basic Lint (Dev Branch)"]
  }

  # Allow direct pushes for development
  enforce_admins      = false
  allows_deletions    = false
  allows_force_pushes = false
  
  depends_on = [github_branch.dev]
}

# Import and configure existing repository settings
resource "github_repository" "detection_rules_settings" {
  name                 = data.github_repository.detection_rules.name
  visibility           = "public"
  has_issues          = true
  has_projects        = false
  has_wiki            = false
  vulnerability_alerts = true
  
  security_and_analysis {
    secret_scanning {
      status = "enabled"
    }
    secret_scanning_push_protection {
      status = "enabled"
    }
  }
}

# Output branch protection status
output "branch_protection_summary" {
  value = {
    main_branch = {
      protected = true
      requires_reviews = 1
      requires_status_checks = ["Lint Detection Rules", "Rule Format Validation"]
      enforced_for_admins = true
    }
    dev_branch = {
      protected = true
      allows_direct_pushes = true
      requires_status_checks = ["Basic Lint (Dev Branch)"]
      enforced_for_admins = false
    }
  }
  description = "Summary of branch protection rules"
}