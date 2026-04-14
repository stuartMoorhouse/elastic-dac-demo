# CRITICAL: Ensure workflows exist in ALL branches before they're used
# This prevents the recurring issue where feature branches don't have workflows

# Create a base workflow file that gets added to EVERY branch on creation
resource "null_resource" "ensure_base_workflows" {
  provisioner "local-exec" {
    command = <<-EOT
      set -e
      
      echo "Setting up GitHub to ALWAYS include workflows in new branches..."
      
      REPO_DIR="../../${local.repo_name}"
      
      # Create a post-checkout hook that adds workflows to any new branch
      if [ -d "$${REPO_DIR}" ]; then
        cd "$${REPO_DIR}"
        
        # Create git hooks directory if it doesn't exist
        mkdir -p .git/hooks
        
        # Create post-checkout hook
        cat > .git/hooks/post-checkout <<'HOOK'
#!/bin/bash
# Auto-add workflows to new branches

# Check if this is a branch checkout (not a file checkout)
if [ "$3" = "1" ]; then
  CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
  echo "Checking workflows in branch: $${CURRENT_BRANCH}"
  
  # If workflows don't exist, copy them from main
  if [ ! -f ".github/workflows/feature-branch-validate.yml" ]; then
    echo "Adding missing workflows to $${CURRENT_BRANCH}..."
    
    # Fetch the workflows from main branch
    git checkout main -- .github/workflows/feature-branch-validate.yml 2>/dev/null || true
    git checkout main -- .github/workflows/pr-validate.yml 2>/dev/null || true
    git checkout main -- .github/workflows/deploy-dev-to-development.yml 2>/dev/null || true
    
    # If files were added, commit them
    if [ -f ".github/workflows/feature-branch-validate.yml" ]; then
      git add .github/workflows/*.yml
      git commit -m "chore: Add workflows to branch $${CURRENT_BRANCH}" || true
    fi
  fi
fi
HOOK
        
        # Make hook executable
        chmod +x .git/hooks/post-checkout
        
        echo "Git hook installed to auto-add workflows to new branches"
      fi
    EOT
  }

  depends_on = [
    null_resource.clone_repository
  ]

  triggers = {
    always_run = timestamp()
  }
}

# ALSO: Pre-populate workflows in the default branch template
resource "github_repository_file" "workflow_template_main" {
  repository = data.github_repository.detection_rules.name
  branch     = "main"
  file       = ".github/WORKFLOW_TEMPLATE.md"

  content = <<-EOT
    # Workflow Template Notice
    
    This repository includes automated workflows that MUST exist in all branches.
    
    When creating a new branch, the following workflows are automatically included:
    - feature-branch-validate.yml - Validates and creates PRs for feature branches
    - pr-validate.yml - Validates pull requests
    - deploy-dev-to-development.yml - Deploys to development environment
    
    DO NOT DELETE THESE WORKFLOWS FROM YOUR BRANCH.
  EOT

  commit_message = "Add workflow template notice"
  commit_author  = "Terraform"
  commit_email   = "terraform@${var.repo_name_prefix}.local"

  depends_on = [
    null_resource.create_fork
  ]
}

# Force sync workflows to any branch created from the GitHub UI
resource "null_resource" "configure_github_default_files" {
  provisioner "local-exec" {
    command = <<-EOT
      set -e
      
      echo "Configuring GitHub to include workflows in all new branches..."
      
      # Use GitHub API to ensure workflows are in the default branch
      gh api repos/${data.github_repository.detection_rules.full_name} \
        --method PATCH \
        --field auto_init=false \
        --field allow_auto_merge=false \
        2>/dev/null || true
      
      # Create a GitHub Action that runs on branch creation to add workflows
      cat > /tmp/branch-create-workflow.yml <<'WORKFLOW'
name: Add Workflows to New Branches
on:
  create:
    branches:
      - 'feature/**'
      - 'fix/**'
      - 'feat/**'

jobs:
  add-workflows:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          ref: $${{ github.ref }}
          token: $${{ secrets.GITHUB_TOKEN }}
      
      - name: Copy workflows from main
        run: |
          git config user.name "GitHub Actions"
          git config user.email "actions@github.com"
          
          # Fetch main branch
          git fetch origin main
          
          # Copy workflows if they don't exist
          if [ ! -f ".github/workflows/feature-branch-validate.yml" ]; then
            git checkout origin/main -- .github/workflows/feature-branch-validate.yml || true
            git checkout origin/main -- .github/workflows/pr-validate.yml || true
            
            if [ -f ".github/workflows/feature-branch-validate.yml" ]; then
              git add .github/workflows/*.yml
              git commit -m "chore: Add required workflows to branch"
              git push
            fi
          fi
WORKFLOW
      
      # Upload this workflow to main branch
      gh api repos/${data.github_repository.detection_rules.full_name}/contents/.github/workflows/add-workflows-to-branches.yml \
        -X PUT \
        -f message="Add workflow to ensure all branches have required workflows" \
        -f content="$(base64 < /tmp/branch-create-workflow.yml)" \
        2>/dev/null || echo "Workflow may already exist"
      
      echo "GitHub configured to add workflows to all new branches"
    EOT
  }

  depends_on = [
    github_repository_file.feature_branch_workflow,
    github_repository_file.pr_validation_workflow
  ]

  triggers = {
    timestamp = timestamp()
  }
}