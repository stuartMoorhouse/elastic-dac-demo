# Remove inherited GitHub Actions workflows from the Elastic detection-rules repository
# These cause confusing failures in the fork

resource "null_resource" "cleanup_inherited_workflows" {
  depends_on = [
    null_resource.clone_repository,
    null_resource.setup_dac_demo_rules
  ]

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      
      REPO_DIR="../../${local.repo_name}"
      
      echo "Cleaning up inherited GitHub Actions workflows from Elastic..."
      
      if [ -d "$${REPO_DIR}/.github/workflows" ]; then
        cd "$${REPO_DIR}"
        
        # List of workflows to remove that come from Elastic and cause issues
        WORKFLOWS_TO_REMOVE=(
          "add-comment.yml"           # Adds PR guidelines comment
          "label-pr.yml"              # Community labeling
          "pr-label.yml"              # Another labeling workflow
          "community-label.yml"       # Community label workflow
          "osquery-validation.yml"    # OSQuery validation we don't need
          "stats-release.yml"         # Stats release workflow
        )
        
        for workflow in "$${WORKFLOWS_TO_REMOVE[@]}"; do
          if [ -f ".github/workflows/$${workflow}" ]; then
            echo "Removing inherited workflow: $${workflow}"
            rm -f ".github/workflows/$${workflow}"
          fi
        done
        
        # Check if there are any remaining workflows that might cause issues
        echo "Checking for other potentially problematic workflows..."
        
        # Remove any workflow that references elastic organization specifics
        for workflow in .github/workflows/*.yml .github/workflows/*.yaml; do
          if [ -f "$${workflow}" ]; then
            # Check if it's one of our custom workflows (keep these)
            if ! grep -q "dac-demo" "$${workflow}" && \
               ! grep -q "deploy-to-prod" "$${workflow}" && \
               ! grep -q "deploy-dev-to-development" "$${workflow}" && \
               ! grep -q "feature-branch-validate" "$${workflow}" && \
               ! grep -q "pr-validate" "$${workflow}" && \
               ! grep -q "rollback" "$${workflow}" && \
               ! grep -q "auto-rollback" "$${workflow}"; then
              # Check if it references elastic-specific resources
              if grep -q "elastic/detection-rules" "$${workflow}" || \
                 grep -q "ELASTIC_" "$${workflow}" || \
                 grep -q "elastic-ci" "$${workflow}" || \
                 grep -q "add-comment" "$${workflow}" || \
                 grep -q "label" "$${workflow}"; then
                echo "Removing elastic-specific workflow: $(basename $${workflow})"
                rm -f "$${workflow}"
              fi
            fi
          fi
        done
        
        # Commit the cleanup if there are changes
        if git status --porcelain | grep -q "^D"; then
          echo "Committing workflow cleanup..."
          git add -A
          git commit -m "chore: Remove inherited Elastic workflows that cause PR failures

- Remove add-comment.yml that tries to add boilerplate
- Remove labeling workflows specific to Elastic's process
- Keep only DAC demo specific workflows"
          
          # Push to all relevant branches
          echo "Pushing cleanup to main branch..."
          git push origin main || echo "Note: May need to push via PR due to branch protection"
          
          # Also push to dev branch if it exists
          if git show-ref --verify --quiet refs/heads/dev; then
            git checkout dev
            git merge main -m "Merge workflow cleanup from main"
            git push origin dev
            git checkout main
          fi
        else
          echo "No workflows needed cleanup"
        fi
      else
        echo "No .github/workflows directory found"
      fi
      
      echo "Workflow cleanup complete!"
    EOT
  }

  triggers = {
    repo_name = local.repo_name
    timestamp = timestamp()  # Force re-run each time
  }
}