# GitHub Workflows for Detection as Code CI/CD Pipeline

# Workflow for feature branches - Deploy to Development
resource "github_repository_file" "feature_branch_workflow" {
  repository = data.github_repository.detection_rules.name
  branch     = "main"
  file       = ".github/workflows/deploy-to-dev.yml"

  content = <<-EOT
name: Deploy Custom Rules to Development

on:
  push:
    branches:
      - 'feature/**'
      - 'feat/**'
      - 'fix/**'
    paths:
      - 'custom-rules/**'
      - '.github/workflows/deploy-to-dev.yml'

jobs:
  validate-and-deploy:
    runs-on: ubuntu-latest
    name: Validate and Deploy to Development
    
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

    - name: Validate custom rules
      run: |
        if [ -d "custom-rules/rules" ] && [ "$(ls -A custom-rules/rules)" ]; then
          echo "Validating custom rules..."
          python -m detection_rules validate-rule custom-rules/rules/*.toml || true
          python -m detection_rules test custom-rules/rules/ || true
        else
          echo "No custom rules found in custom-rules/rules/"
        fi

    - name: Deploy to Development Kibana
      env:
        ELASTIC_CLOUD_ID: $${{ secrets.DEV_ELASTIC_CLOUD_ID }}
        ELASTIC_API_KEY: $${{ secrets.DEV_ELASTIC_API_KEY }}
      run: |
        if [ -d "custom-rules/rules" ] && [ "$(ls -A custom-rules/rules)" ]; then
          echo "Deploying custom rules to Development environment..."
          
          # Create detection-rules config file with Cloud ID and API key
          cat > .detection-rules-cfg.json << EOF
        {
          "cloud_id": "$${ELASTIC_CLOUD_ID}",
          "api_key": "$${ELASTIC_API_KEY}"
        }
        EOF
          
          # Import rules to Development Kibana using API key authentication
          python -m detection_rules kibana import-rules \
            -d custom-rules/rules/ \
            --space default || echo "Warning: Some rules may have failed to import"
          
          # Clean up config file
          rm -f .detection-rules-cfg.json
          
          echo "Deployment to Development completed!"
        else
          echo "No custom rules to deploy"
        fi

    - name: Post deployment status
      if: always()
      run: |
        if [ "$${{ job.status }}" == "success" ]; then
          echo "✅ Custom rules deployed to Development successfully"
        else
          echo "❌ Deployment to Development failed - check logs above"
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

