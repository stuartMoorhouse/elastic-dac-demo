# Sync workflows to all branches so they can trigger properly
# GitHub Actions only runs workflows that exist in the branch being pushed

# Copy feature branch workflow to dev branch
resource "github_repository_file" "feature_branch_workflow_dev" {
  repository = data.github_repository.detection_rules.name
  branch     = github_branch.dev.branch
  file       = ".github/workflows/feature-branch-validate.yml"

  # Use the same content as the main branch version
  content = github_repository_file.feature_branch_workflow.content

  commit_message = "Sync feature branch workflow to dev branch"
  commit_author  = "Terraform"
  commit_email   = "terraform@${var.repo_name_prefix}.local"

  lifecycle {
    ignore_changes = [commit_message, commit_author, commit_email]
  }

  depends_on = [
    github_branch.dev,
    github_repository_file.feature_branch_workflow
  ]
}

# Also ensure PR validation workflow is in dev branch
resource "github_repository_file" "pr_validation_workflow_dev" {
  repository = data.github_repository.detection_rules.name
  branch     = github_branch.dev.branch
  file       = ".github/workflows/pr-validate.yml"

  # Use the same content as the main branch version
  content = github_repository_file.pr_validation_workflow.content

  commit_message = "Sync PR validation workflow to dev branch"
  commit_author  = "Terraform"
  commit_email   = "terraform@${var.repo_name_prefix}.local"

  lifecycle {
    ignore_changes = [commit_message, commit_author, commit_email]
  }

  depends_on = [
    github_branch.dev,
    github_repository_file.pr_validation_workflow
  ]
}

# Ensure all other necessary workflows are in dev branch
resource "github_repository_file" "dev_branch_workflow_dev" {
  repository = data.github_repository.detection_rules.name
  branch     = github_branch.dev.branch
  file       = ".github/workflows/deploy-dev-to-development.yml"

  content = github_repository_file.dev_branch_deploy_workflow.content

  commit_message = "Sync dev deployment workflow to dev branch"
  commit_author  = "Terraform"
  commit_email   = "terraform@${var.repo_name_prefix}.local"

  lifecycle {
    ignore_changes = [commit_message, commit_author, commit_email]
  }

  depends_on = [
    github_branch.dev,
    github_repository_file.dev_branch_deploy_workflow
  ]
}

# Also copy main deployment workflow to dev branch so it's available
resource "github_repository_file" "main_workflow_dev" {
  repository = data.github_repository.detection_rules.name
  branch     = github_branch.dev.branch
  file       = ".github/workflows/deploy-to-prod.yml"

  content = github_repository_file.main_branch_workflow.content

  commit_message = "Sync main deployment workflow to dev branch"
  commit_author  = "Terraform"
  commit_email   = "terraform@${var.repo_name_prefix}.local"

  lifecycle {
    ignore_changes = [commit_message, commit_author, commit_email]
  }

  depends_on = [
    github_branch.dev,
    github_repository_file.main_branch_workflow
  ]
}

# Copy rollback workflows to dev branch
resource "github_repository_file" "rollback_workflow_dev" {
  repository = data.github_repository.detection_rules.name
  branch     = github_branch.dev.branch
  file       = ".github/workflows/rollback-rules.yml"

  content = github_repository_file.rollback_workflow.content

  commit_message = "Sync rollback workflow to dev branch"
  commit_author  = "Terraform"
  commit_email   = "terraform@${var.repo_name_prefix}.local"

  lifecycle {
    ignore_changes = [commit_message, commit_author, commit_email]
  }

  depends_on = [
    github_branch.dev,
    github_repository_file.rollback_workflow
  ]
}

resource "github_repository_file" "auto_rollback_workflow_dev" {
  repository = data.github_repository.detection_rules.name
  branch     = github_branch.dev.branch
  file       = ".github/workflows/auto-rollback.yml"

  content = github_repository_file.auto_rollback_workflow.content

  commit_message = "Sync auto-rollback workflow to dev branch"
  commit_author  = "Terraform"
  commit_email   = "terraform@${var.repo_name_prefix}.local"

  lifecycle {
    ignore_changes = [commit_message, commit_author, commit_email]
  }

  depends_on = [
    github_branch.dev,
    github_repository_file.auto_rollback_workflow
  ]
}

# Additionally, create a null_resource to ensure workflows are in any existing feature branches
resource "null_resource" "sync_workflows_to_existing_branches" {
  provisioner "local-exec" {
    command = <<-EOT
      set -e
      
      echo "Syncing workflows to all existing branches..."
      
      # Get all branches with pagination
      ALL_BRANCHES=$(gh api repos/${data.github_repository.detection_rules.full_name}/branches --paginate --jq '.[].name' || echo "")
      
      for BRANCH in $${ALL_BRANCHES}; do
        echo "Checking branch: $${BRANCH}"
        
        # Check if workflow exists in this branch
        WORKFLOW_EXISTS=$(gh api repos/${data.github_repository.detection_rules.full_name}/contents/.github/workflows/feature-branch-validate.yml?ref=$${BRANCH} --jq '.name' 2>/dev/null || echo "")
        
        if [ -z "$${WORKFLOW_EXISTS}" ]; then
          echo "Adding workflows to branch: $${BRANCH}"
          
          # Get the workflow content from main branch
          WORKFLOW_CONTENT=$(gh api repos/${data.github_repository.detection_rules.full_name}/contents/.github/workflows/feature-branch-validate.yml?ref=main --jq '.content' 2>/dev/null || echo "")
          PR_WORKFLOW_CONTENT=$(gh api repos/${data.github_repository.detection_rules.full_name}/contents/.github/workflows/pr-validate.yml?ref=main --jq '.content' 2>/dev/null || echo "")
          
          if [ ! -z "$${WORKFLOW_CONTENT}" ]; then
            # Create the workflows directory first if needed
            gh api repos/${data.github_repository.detection_rules.full_name}/contents/.github/workflows \
              -X PUT \
              -f message="Create workflows directory in $${BRANCH}" \
              -f content="" \
              -f branch="$${BRANCH}" \
              2>/dev/null || true
            
            # Add feature branch workflow
            gh api repos/${data.github_repository.detection_rules.full_name}/contents/.github/workflows/feature-branch-validate.yml \
              -X PUT \
              -f message="Add feature branch workflow to $${BRANCH}" \
              -f content="$${WORKFLOW_CONTENT}" \
              -f branch="$${BRANCH}" \
              2>/dev/null || echo "Could not add feature workflow to $${BRANCH}"
            
            # Add PR validation workflow
            if [ ! -z "$${PR_WORKFLOW_CONTENT}" ]; then
              gh api repos/${data.github_repository.detection_rules.full_name}/contents/.github/workflows/pr-validate.yml \
                -X PUT \
                -f message="Add PR validation workflow to $${BRANCH}" \
                -f content="$${PR_WORKFLOW_CONTENT}" \
                -f branch="$${BRANCH}" \
                2>/dev/null || echo "Could not add PR workflow to $${BRANCH}"
            fi
            
            echo "✓ Workflows added to $${BRANCH}"
          fi
        else
          echo "✓ Workflows already exist in $${BRANCH}"
        fi
      done
      
      echo "Workflow sync complete!"
    EOT
  }

  triggers = {
    workflow_content = md5(github_repository_file.feature_branch_workflow.content)
    timestamp        = timestamp()
  }

  depends_on = [
    github_repository_file.feature_branch_workflow,
    github_repository_file.feature_branch_workflow_dev
  ]
}