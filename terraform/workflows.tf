# GitHub Workflows for Detection as Code CI/CD Pipeline

# Workflow for feature branches - Validation only (no automatic deployment)
resource "github_repository_file" "feature_branch_workflow" {
  repository = data.github_repository.detection_rules.name
  branch     = "main"
  file       = ".github/workflows/feature-branch-validate.yml"

  content = <<-EOT
name: Validate Feature Branch Rules

on:
  push:
    branches:
      - 'feature/**'
      - 'feat/**'
      - 'fix/**'
    paths:
      - 'custom-rules/**'
      - '.github/workflows/feature-branch-validate.yml'

jobs:
  validate-only:
    runs-on: ubuntu-latest
    name: Validate Detection Rules
    
    steps:
    - name: Checkout repository
      uses: actions/checkout@v4
      with:
        fetch-depth: 0

    - name: Set up Python
      uses: actions/setup-python@v5
      with:
        python-version: '3.11'

    - name: Install detection-rules dependencies
      run: |
        python -m pip install --upgrade pip
        pip install .
        pip install lib/kibana
        pip install lib/kql

    - name: Set up custom rules directory
      run: |
        # Create custom-rules directory if it doesn't exist
        mkdir -p custom-rules/rules
        
        # Set environment variable for custom rules
        echo "CUSTOM_RULES_DIR=./custom-rules" >> $GITHUB_ENV

    - name: Validate custom rules syntax
      run: |
        if [ -d "custom-rules/rules" ] && [ "$(ls -A custom-rules/rules)" ]; then
          echo "Validating custom rules syntax..."
          for rule in custom-rules/rules/*.toml; do
            if [ -f "$rule" ]; then
              echo "Validating: $rule"
              python -m detection_rules validate-rule "$rule"
            fi
          done
          echo "✅ All rules have valid syntax"
        else
          echo "No custom rules found in custom-rules/rules/"
        fi

    - name: Run detection rules tests
      run: |
        if [ -d "custom-rules/rules" ] && [ "$(ls -A custom-rules/rules)" ]; then
          echo "Running detection rules tests..."
          python -m detection_rules test custom-rules/rules/
          echo "✅ All tests passed"
        else
          echo "No custom rules to test"
        fi

    - name: Generate validation report
      if: always()
      run: |
        echo "## 📊 Feature Branch Validation Report" >> $$GITHUB_STEP_SUMMARY
        echo "" >> $$GITHUB_STEP_SUMMARY
        
        if [ -d "custom-rules/rules" ] && [ "$(ls -A custom-rules/rules)" ]; then
          RULE_COUNT=$(find custom-rules/rules -name "*.toml" -type f | wc -l | tr -d ' ')
          echo "- **Rules validated**: $${RULE_COUNT}" >> $$GITHUB_STEP_SUMMARY
        else
          echo "- **Rules validated**: 0 (no custom rules found)" >> $$GITHUB_STEP_SUMMARY
        fi
        
        echo "- **Branch**: $${{ github.ref_name }}" >> $$GITHUB_STEP_SUMMARY
        echo "- **Commit**: $${{ github.sha }}" >> $$GITHUB_STEP_SUMMARY
        echo "" >> $$GITHUB_STEP_SUMMARY
        
        if [ "$${{ job.status }}" == "success" ]; then
          echo "### ✅ Validation Passed" >> $$GITHUB_STEP_SUMMARY
          echo "" >> $$GITHUB_STEP_SUMMARY
          echo "Your rules are valid! A Pull Request will be created automatically." >> $$GITHUB_STEP_SUMMARY
        else
          echo "### ❌ Validation Failed" >> $$GITHUB_STEP_SUMMARY
          echo "" >> $$GITHUB_STEP_SUMMARY
          echo "Please fix the validation errors. No Pull Request will be created." >> $$GITHUB_STEP_SUMMARY
        fi

    - name: Create Pull Request to dev branch
      if: success()
      env:
        GH_TOKEN: $${{ secrets.GH_PAT }}
      run: |
        echo "Creating Pull Request to dev branch..."
        
        # Extract branch type and name for PR title
        BRANCH_NAME="$${{ github.ref_name }}"
        BRANCH_TYPE=$(echo "$${BRANCH_NAME}" | cut -d'/' -f1)
        BRANCH_DESC=$(echo "$${BRANCH_NAME}" | cut -d'/' -f2- | tr '-' ' ')
        
        # Create appropriate PR title based on branch type
        case "$${BRANCH_TYPE}" in
          feature|feat)
            PR_TITLE="feat: $${BRANCH_DESC}"
            ;;
          fix)
            PR_TITLE="fix: $${BRANCH_DESC}"
            ;;
          *)
            PR_TITLE="chore: $${BRANCH_DESC}"
            ;;
        esac
        
        # Check if PR already exists
        EXISTING_PR=$(gh pr list --head "$${BRANCH_NAME}" --base dev --json number --jq '.[0].number' || echo "")
        
        if [ -n "$${EXISTING_PR}" ]; then
          echo "Pull Request #$${EXISTING_PR} already exists for this branch"
          echo "View it at: $${{ github.server_url }}/$${{ github.repository }}/pull/$${EXISTING_PR}"
        else
          # Create the Pull Request
          PR_URL=$(gh pr create \
            --title "$${PR_TITLE}" \
            --body "## Automated Pull Request
        
        This PR was automatically created after successful validation of detection rules.
        
        ### Validation Results
        - ✅ Syntax validation passed
        - ✅ Detection rules tests passed
        - ✅ Ready for deployment to Development environment
        
        ### Branch Information
        - **Source Branch**: \`$${{ github.ref_name }}\`
        - **Target Branch**: \`dev\`
        - **Commit**: $${{ github.sha }}
        
        ### Next Steps
        1. Review the changes in this PR
        2. Approve and merge to deploy to Development environment
        3. After testing in Development, create a PR from \`dev\` to \`main\` for Production
        
        ---
        *This PR was automatically generated by the Detection as Code CI/CD pipeline.*" \
            --base dev \
            --head "$${BRANCH_NAME}" || echo "FAILED")
          
          if [ "$${PR_URL}" != "FAILED" ] && [ -n "$${PR_URL}" ]; then
            echo "✅ Pull Request created successfully!"
            echo "View it at: $${PR_URL}"
            echo "" >> $$GITHUB_STEP_SUMMARY
            echo "### 🎉 Pull Request Created" >> $$GITHUB_STEP_SUMMARY
            echo "PR URL: $${PR_URL}" >> $$GITHUB_STEP_SUMMARY
          else
            echo "Failed to create Pull Request. You may need to create it manually."
            echo "This can happen if:"
            echo "- The branch is not pushed to the remote"
            echo "- There are no changes between branches"
            echo "- Permission issues with the GitHub token"
          fi
        fi
EOT

  commit_message = "Add feature branch workflow for deploying to development"
  commit_author  = "Terraform"
  commit_email   = "terraform@${var.repo_name_prefix}.local"

  lifecycle {
    ignore_changes = [commit_message, commit_author, commit_email]
  }

  depends_on = [
    null_resource.clone_repository,
    data.github_repository.detection_rules
  ]
}

# Workflow for main branch - Deploy to Production
resource "github_repository_file" "main_branch_workflow" {
  repository = data.github_repository.detection_rules.name
  branch     = "main"
  file       = ".github/workflows/deploy-to-prod.yml"

  content = <<-EOT
name: Deploy Custom Rules to Production

on:
  push:
    branches:
      - main
    paths:
      - 'custom-rules/**'
      - '.github/workflows/deploy-to-prod.yml'
  pull_request:
    types: [closed]
    branches:
      - main

jobs:
  validate-and-deploy:
    # Only run if it's a direct push or a merged PR
    if: github.event_name == 'push' || (github.event_name == 'pull_request' && github.event.pull_request.merged == true)
    runs-on: ubuntu-latest
    name: Validate and Deploy to Production
    
    steps:
    - name: Checkout repository
      uses: actions/checkout@v4
      with:
        fetch-depth: 0

    - name: Set up Python
      uses: actions/setup-python@v5
      with:
        python-version: '3.11'

    - name: Install detection-rules dependencies
      run: |
        python -m pip install --upgrade pip
        pip install .
        pip install lib/kibana
        pip install lib/kql

    - name: Set up custom rules directory
      run: |
        # Create custom-rules directory if it doesn't exist
        mkdir -p custom-rules/rules
        
        # Set environment variable for custom rules
        echo "CUSTOM_RULES_DIR=./custom-rules" >> $GITHUB_ENV

    - name: Run comprehensive validation
      run: |
        if [ -d "custom-rules/rules" ] && [ "$(ls -A custom-rules/rules)" ]; then
          echo "Running comprehensive validation for Production deployment..."
          
          # Validate rule syntax
          python -m detection_rules validate-rule custom-rules/rules/*.toml
          
          # Run tests
          python -m detection_rules test custom-rules/rules/
          
          echo "All validations passed!"
        else
          echo "No custom rules found in custom-rules/rules/"
        fi

    - name: Build release and update version lock
      run: |
        echo "Building release and updating version lock for production..."
        
        # Build release with version lock update
        python -m detection_rules dev build-release --update-version-lock
        
        # Check if version.lock was modified
        if git diff --name-only | grep -q "version.lock"; then
          echo "Version lock has been updated"
          
          # Configure git for the commit
          git config --local user.email "github-actions[bot]@users.noreply.github.com"
          git config --local user.name "github-actions[bot]"
          
          # Commit the version lock
          git add version.lock
          git commit -m "chore: Update version.lock for production release
          
          Auto-generated by GitHub Actions deployment to production
          [skip ci]"
          
          # Push the changes back to main
          git push origin main
          
          echo "Version lock committed and pushed to main branch"
        else
          echo "No changes to version.lock"
        fi

    - name: Deploy to Production Kibana
      env:
        ELASTIC_CLOUD_ID: $${{ secrets.PROD_ELASTIC_CLOUD_ID }}
        ELASTIC_API_KEY: $${{ secrets.PROD_ELASTIC_API_KEY }}
      run: |
        if [ -d "custom-rules/rules" ] && [ "$(ls -A custom-rules/rules)" ]; then
          echo "🚀 Deploying custom rules to Production environment..."
          
          # Create detection-rules config file with Cloud ID and API key
          cat > .detection-rules-cfg.json << EOF
        {
          "cloud_id": "$${ELASTIC_CLOUD_ID}",
          "api_key": "$${ELASTIC_API_KEY}"
        }
        EOF
          
          # Import rules to Production Kibana using API key authentication
          python -m detection_rules kibana import-rules \
            -d custom-rules/rules/ \
            --space default
          
          # Clean up config file
          rm -f .detection-rules-cfg.json
          
          echo "✅ Production deployment completed successfully!"
        else
          echo "No custom rules to deploy to Production"
        fi

    - name: Create deployment notification
      if: success()
      run: |
        echo "## 🎉 Production Deployment Successful" >> $$GITHUB_STEP_SUMMARY
        echo "" >> $$GITHUB_STEP_SUMMARY
        echo "Custom detection rules have been deployed to the Production environment." >> $$GITHUB_STEP_SUMMARY
        echo "" >> $$GITHUB_STEP_SUMMARY
        echo "- **Environment**: Production" >> $$GITHUB_STEP_SUMMARY
        echo "- **Commit**: $${{ github.sha }}" >> $$GITHUB_STEP_SUMMARY
        echo "- **Triggered by**: $${{ github.actor }}" >> $$GITHUB_STEP_SUMMARY
        echo "- **Time**: $$(date -u '+%Y-%m-%d %H:%M:%S UTC')" >> $$GITHUB_STEP_SUMMARY

    - name: Rollback on failure
      if: failure()
      run: |
        echo "❌ Production deployment failed!" >> $$GITHUB_STEP_SUMMARY
        echo "" >> $$GITHUB_STEP_SUMMARY
        echo "The deployment to Production has failed. Please review the logs above." >> $$GITHUB_STEP_SUMMARY
        echo "Manual intervention may be required to restore service." >> $$GITHUB_STEP_SUMMARY
        exit 1
EOT

  commit_message = "Add main branch workflow for deploying to production"
  commit_author  = "Terraform"
  commit_email   = "terraform@${var.repo_name_prefix}.local"

  lifecycle {
    ignore_changes = [commit_message, commit_author, commit_email]
  }

  depends_on = [
    null_resource.clone_repository,
    data.github_repository.detection_rules
  ]
}

# Note: GitHub Actions secrets are now managed by elastic_api_keys.tf
# The secrets are created via the GitHub CLI in null_resource.update_github_secrets
# Secrets created:
# - DEV_ELASTIC_CLOUD_ID: Cloud ID for Development cluster
# - DEV_ELASTIC_API_KEY: API key for Development cluster
# - PROD_ELASTIC_CLOUD_ID: Cloud ID for Production cluster  
# - PROD_ELASTIC_API_KEY: API key for Production cluster

