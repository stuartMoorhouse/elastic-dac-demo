# Data source to get repository information after fork is created
data "github_repository" "detection_rules" {
  full_name = "${data.external.github_user.result.login}/${local.repo_name}"

  depends_on = [
    null_resource.create_fork,
    null_resource.clone_repository # This ensures the repo is fully created and cloned
  ]
}

# Create dev branch if it doesn't exist
resource "github_branch" "dev" {
  repository    = data.github_repository.detection_rules.name
  branch        = "dev"
  source_branch = data.github_repository.detection_rules.default_branch # Use the actual default branch

  # The data source above will only succeed when the repository exists
  # No arbitrary waiting needed
  depends_on = [
    data.github_repository.detection_rules
  ]
}

# Main branch protection - Production
# Applied AFTER workflows are created to avoid blocking them
resource "github_branch_protection" "main" {
  repository_id = data.github_repository.detection_rules.name
  pattern       = "main"

  required_status_checks {
    strict   = true
    contexts = ["validate-rules"] # Require validation workflow to pass
  }

  required_pull_request_reviews {
    dismiss_stale_reviews           = true
    require_code_owner_reviews      = false
    required_approving_review_count = 1
  }

  enforce_admins                  = true
  allows_deletions                = false
  allows_force_pushes             = false
  required_linear_history         = true # Enforce linear history (rebase before merge)
  require_conversation_resolution = true # Ensure all PR comments are resolved
  require_signed_commits          = false

  # CRITICAL: Apply branch protection AFTER workflows are created
  depends_on = [
    github_repository_file.feature_branch_workflow,
    github_repository_file.main_branch_workflow,
    github_repository_file.dev_branch_validation_workflow,
    github_repository_file.pr_validation_workflow,
    github_branch.dev
  ]
}

# Dev branch protection - Development
resource "github_branch_protection" "dev" {
  repository_id = data.github_repository.detection_rules.name
  pattern       = "dev"

  required_status_checks {
    strict   = false
    contexts = []
  }

  enforce_admins      = false
  allows_deletions    = false
  allows_force_pushes = false

  # Apply after workflows are created
  depends_on = [
    github_branch.dev,
    github_repository_file.feature_branch_workflow,
    github_repository_file.main_branch_workflow,
    github_repository_file.dev_branch_validation_workflow
  ]
}

# Output branch protection status
output "branch_protection_summary" {
  value = {
    main_branch = {
      protected                        = true
      requires_pr                      = true
      requires_approval                = true
      enforced_for_admins              = true
      status_checks_required           = ["validate-rules"]
      requires_linear_history          = true
      merge_strategy                   = "regular merge (no squash)"
      requires_conversation_resolution = true
    }
    dev_branch = {
      protected           = true
      allows_direct_push  = true
      enforced_for_admins = false
      status_checks       = "basic validation only"
    }
  }
  description = "Summary of branch protection rules"

  depends_on = [
    github_branch_protection.main,
    github_branch_protection.dev
  ]
}