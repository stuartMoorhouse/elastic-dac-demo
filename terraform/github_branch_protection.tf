# Branch protection rules for Detection as Code repository

# Data source to get the repository
data "github_repository" "detection_rules" {
  name = "${var.repo_name_prefix}-detection-rules"
}

# Create dev branch if it doesn't exist
resource "github_branch" "dev" {
  repository    = data.github_repository.detection_rules.name
  branch        = "dev"
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

  # Require status checks from pythonpackage.yml workflow
  required_status_checks {
    strict   = true
    contexts = ["build"]
  }

  # Enforce for admins - blocks all direct pushes
  enforce_admins = true

  # Block direct pushes and destructive actions
  allows_deletions    = false
  allows_force_pushes = false
}

# Dev branch protection - Development
resource "github_branch_protection" "dev" {
  repository_id = data.github_repository.detection_rules.node_id
  pattern       = "dev"

  # SECURITY BEST PRACTICE: Require validation to pass before merge
  # This prevents broken detection rules from being committed
  required_status_checks {
    strict   = true # Must be up-to-date with base branch
    contexts = ["build"]
  }

  # Enforce for admins to ensure no bypassing of validation
  enforce_admins      = true
  allows_deletions    = false
  allows_force_pushes = false

  depends_on = [github_branch.dev]
}

# Import and configure existing repository settings
resource "github_repository" "detection_rules_settings" {
  name                 = data.github_repository.detection_rules.name
  visibility           = "public"
  has_issues           = true
  has_projects         = false
  has_wiki             = false
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
      protected              = true
      requires_reviews       = 1
      requires_status_checks = ["build"]
      enforced_for_admins    = true
      direct_pushes_blocked  = true
    }
    dev_branch = {
      protected              = true
      allows_direct_pushes   = true
      requires_status_checks = ["build"]
      enforced_for_admins    = true
      validation_must_pass   = true
    }
  }
  description = "Summary of branch protection rules"
}