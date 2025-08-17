# Create a workflow for dev branch that validates and deploys to Development environment
# This runs when code is merged to dev branch (after PR approval)

resource "github_repository_file" "dev_branch_deploy_workflow" {
  repository = data.github_repository.detection_rules.name
  branch     = "dev"
  file       = ".github/workflows/deploy-dev-to-development.yml"

  depends_on = [
    github_branch.dev, # Dev branch must exist first
    data.github_repository.detection_rules
  ]

  content = <<-EOT
name: Deploy Dev Branch to Development Environment

on:
  push:
    branches: [ "dev" ]
    paths:
      - 'custom-rules/**'
      - '.github/workflows/deploy-dev-to-development.yml'

jobs:
  validate-and-deploy:
    runs-on: ubuntu-latest
    name: Validate and Deploy to Development
    
    steps:
    - name: Checkout repository
      uses: actions/checkout@v4
      with:
        fetch-depth: 0

    - name: Set up Python 3.11
      uses: actions/setup-python@v5
      with:
        python-version: '3.11'

    - name: Install detection-rules dependencies
      run: |
        python -m pip install --upgrade pip
        pip install .[dev]
        pip install lib/kibana
        pip install lib/kql

    - name: Validate all rules
      run: |
        echo "Running comprehensive validation for Development deployment..."
        
        # Validate built-in rules
        python -m detection_rules test
        
        # Validate custom rules if they exist
        if [ -d "custom-rules/rules" ] && [ "$(ls -A custom-rules/rules)" ]; then
          echo "Validating custom rules..."
          python -m detection_rules validate-rule custom-rules/rules/*.toml
          python -m detection_rules test custom-rules/rules/
        fi
        
        echo "All validations passed!"

    - name: Deploy to Development Kibana
      env:
        ELASTIC_CLOUD_ID: $${{ secrets.DEV_ELASTIC_CLOUD_ID }}
        ELASTIC_API_KEY: $${{ secrets.DEV_ELASTIC_API_KEY }}
      run: |
        if [ -d "custom-rules/rules" ] && [ "$(ls -A custom-rules/rules)" ]; then
          echo "Deploying custom rules to Development environment..."
          
          # Create detection-rules config file
          cat > .detection-rules-cfg.json << EOF
        {
          "cloud_id": "$${ELASTIC_CLOUD_ID}",
          "api_key": "$${ELASTIC_API_KEY}"
        }
        EOF
          
          # Import rules to Development Kibana
          python -m detection_rules kibana import-rules \
            -d custom-rules/rules/ \
            --space default
          
          # Clean up config file
          rm -f .detection-rules-cfg.json
          
          echo "✅ Development deployment completed successfully!"
        else
          echo "No custom rules to deploy to Development"
        fi

    - name: Create deployment summary
      if: always()
      run: |
        echo "## 🚀 Development Environment Deployment" >> $$GITHUB_STEP_SUMMARY
        echo "" >> $$GITHUB_STEP_SUMMARY
        
        if [ "$${{ job.status }}" == "success" ]; then
          echo "### ✅ Deployment Successful" >> $$GITHUB_STEP_SUMMARY
          echo "" >> $$GITHUB_STEP_SUMMARY
          echo "Custom detection rules have been deployed to the Development environment." >> $$GITHUB_STEP_SUMMARY
          echo "" >> $$GITHUB_STEP_SUMMARY
          echo "- **Environment**: Development" >> $$GITHUB_STEP_SUMMARY
          echo "- **Branch**: dev" >> $$GITHUB_STEP_SUMMARY
          echo "- **Commit**: $${{ github.sha }}" >> $$GITHUB_STEP_SUMMARY
          echo "" >> $$GITHUB_STEP_SUMMARY
          echo "Next steps:" >> $$GITHUB_STEP_SUMMARY
          echo "1. Test the rules in the Development environment" >> $$GITHUB_STEP_SUMMARY
          echo "2. Once validated, create a PR from \`dev\` to \`main\` for Production deployment" >> $$GITHUB_STEP_SUMMARY
        else
          echo "### ❌ Deployment Failed" >> $$GITHUB_STEP_SUMMARY
          echo "" >> $$GITHUB_STEP_SUMMARY
          echo "The deployment to Development has failed. Please review the logs above." >> $$GITHUB_STEP_SUMMARY
        fi
EOT

  commit_message = "Add dev branch deployment workflow for ${var.repo_name_prefix}"
  commit_author  = "Terraform"
  commit_email   = "terraform@${var.repo_name_prefix}.local"

  lifecycle {
    ignore_changes = [commit_message, commit_author, commit_email]
  }
}

# Output to confirm workflow creation
output "dev_deployment_workflow_path" {
  value       = github_repository_file.dev_branch_deploy_workflow.file
  description = "Path to the dev branch deployment workflow"
}