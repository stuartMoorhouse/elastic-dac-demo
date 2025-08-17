# Rollback workflow for Detection Rules
# Provides manual and automatic rollback capabilities

resource "github_repository_file" "rollback_workflow" {
  repository = data.github_repository.detection_rules.name
  branch     = "main"
  file       = ".github/workflows/rollback-rules.yml"

  content = <<-EOT
name: Rollback Detection Rules

on:
  workflow_dispatch:
    inputs:
      environment:
        description: 'Environment to rollback'
        required: true
        type: choice
        options:
          - development
          - production
      rollback_type:
        description: 'Type of rollback'
        required: true
        type: choice
        options:
          - last_known_good
          - specific_commit
      commit_sha:
        description: 'Specific commit SHA (only for specific_commit type)'
        required: false
        type: string

jobs:
  rollback:
    runs-on: ubuntu-latest
    name: Rollback Detection Rules
    
    steps:
    - name: Checkout repository
      uses: actions/checkout@v4
      with:
        fetch-depth: 0  # Get full history for rollback

    - name: Validate inputs
      run: |
        if [ "$${{ inputs.rollback_type }}" == "specific_commit" ] && [ -z "$${{ inputs.commit_sha }}" ]; then
          echo "❌ Error: Commit SHA is required for specific_commit rollback type"
          exit 1
        fi

    - name: Set up Python
      uses: actions/setup-python@v5
      with:
        python-version: '3.11'

    - name: Install detection-rules dependencies
      run: |
        python -m pip install --upgrade pip
        pip install .[dev]
        pip install lib/kibana
        pip install lib/kql

    - name: Determine rollback target
      id: rollback_target
      run: |
        if [ "$${{ inputs.rollback_type }}" == "last_known_good" ]; then
          # Find the last successful deployment commit
          # Look for commits with successful workflow runs
          echo "Finding last known good deployment..."
          
          # Get the last 10 commits that modified custom-rules
          COMMITS=$(git log --pretty=format:"%H" -n 10 -- custom-rules/)
          
          for commit in $${COMMITS}; do
            # Check if this commit had a successful workflow run
            # For now, we'll use the second-to-last commit as a simple approach
            # In production, you'd query GitHub API for successful workflow runs
            if [ "$${commit}" != "$${{ github.sha }}" ]; then
              echo "rollback_commit=$${commit}" >> $$GITHUB_OUTPUT
              echo "Found rollback target: $${commit}"
              break
            fi
          done
        else
          # Use specific commit
          echo "rollback_commit=$${{ inputs.commit_sha }}" >> $$GITHUB_OUTPUT
          echo "Using specific commit: $${{ inputs.commit_sha }}"
        fi

    - name: Export current rules (backup)
      env:
        ELASTIC_CLOUD_ID: $${{ inputs.environment == 'production' && secrets.PROD_ELASTIC_CLOUD_ID || secrets.DEV_ELASTIC_CLOUD_ID }}
        ELASTIC_API_KEY: $${{ inputs.environment == 'production' && secrets.PROD_ELASTIC_API_KEY || secrets.DEV_ELASTIC_API_KEY }}
      run: |
        echo "Creating backup of current rules..."
        
        # Create detection-rules config file
        cat > .detection-rules-cfg.json << EOF
        {
          "cloud_id": "$${ELASTIC_CLOUD_ID}",
          "api_key": "$${ELASTIC_API_KEY}"
        }
        EOF
        
        # Export current rules as backup
        mkdir -p rollback-backup
        python -m detection_rules kibana export-rules \
          -d rollback-backup/ \
          --space default || echo "Warning: Some rules may have failed to export"
        
        # Store backup info
        echo "Backup created at: $$(date -u '+%Y-%m-%d %H:%M:%S UTC')" > rollback-backup/backup-info.txt
        echo "Environment: $${{ inputs.environment }}" >> rollback-backup/backup-info.txt
        echo "Original commit: $${{ github.sha }}" >> rollback-backup/backup-info.txt

    - name: Checkout rollback commit
      run: |
        echo "Checking out rollback commit: $${{ steps.rollback_target.outputs.rollback_commit }}"
        git checkout $${{ steps.rollback_target.outputs.rollback_commit }}

    - name: Validate rollback rules
      run: |
        if [ -d "custom-rules/rules" ] && [ "$(ls -A custom-rules/rules)" ]; then
          echo "Validating rollback rules..."
          python -m detection_rules validate-rule custom-rules/rules/*.toml
          python -m detection_rules test custom-rules/rules/
          echo "✅ Rollback rules validated successfully"
        else
          echo "No custom rules found at rollback commit"
        fi

    - name: Deploy rollback rules
      env:
        ELASTIC_CLOUD_ID: $${{ inputs.environment == 'production' && secrets.PROD_ELASTIC_CLOUD_ID || secrets.DEV_ELASTIC_CLOUD_ID }}
        ELASTIC_API_KEY: $${{ inputs.environment == 'production' && secrets.PROD_ELASTIC_API_KEY || secrets.DEV_ELASTIC_API_KEY }}
      run: |
        echo "🔄 Rolling back $${{ inputs.environment }} environment..."
        
        # Create detection-rules config file
        cat > .detection-rules-cfg.json << EOF
        {
          "cloud_id": "$${ELASTIC_CLOUD_ID}",
          "api_key": "$${ELASTIC_API_KEY}"
        }
        EOF
        
        if [ -d "custom-rules/rules" ] && [ "$(ls -A custom-rules/rules)" ]; then
          # Import rollback rules
          python -m detection_rules kibana import-rules \
            -d custom-rules/rules/ \
            --space default \
            --overwrite
          
          echo "✅ Rollback completed successfully!"
        else
          echo "⚠️ No rules to rollback to - environment may need manual restoration"
        fi
        
        # Clean up config file
        rm -f .detection-rules-cfg.json

    - name: Create rollback record
      if: always()
      env:
        GH_TOKEN: $${{ secrets.GH_PAT }}
      run: |
        # Create an issue to track the rollback
        gh issue create \
          --title "🔄 Rollback: $${{ inputs.environment }} environment" \
          --body "## Rollback Record
        
        ### Rollback Details
        - **Environment**: $${{ inputs.environment }}
        - **Rollback Type**: $${{ inputs.rollback_type }}
        - **Rolled back to**: $${{ steps.rollback_target.outputs.rollback_commit }}
        - **Triggered by**: $${{ github.actor }}
        - **Time**: $$(date -u '+%Y-%m-%d %H:%M:%S UTC')
        
        ### Status
        - **Result**: $${{ job.status }}
        
        ### Action Required
        - Review the rollback and determine root cause
        - Fix the issue that caused the need for rollback
        - Re-deploy fixed rules when ready
        
        ### Backup Location
        The pre-rollback rules were backed up and can be found in the workflow artifacts.
        
        ---
        *This issue was automatically created by the rollback workflow.*" \
          --label "rollback,$${{ inputs.environment }}"

    - name: Upload backup artifacts
      if: always()
      uses: actions/upload-artifact@v4
      with:
        name: rollback-backup-$${{ inputs.environment }}-$${{ github.run_id }}
        path: rollback-backup/
        retention-days: 30

    - name: Generate rollback summary
      if: always()
      run: |
        echo "## 🔄 Rollback Summary" >> $$GITHUB_STEP_SUMMARY
        echo "" >> $$GITHUB_STEP_SUMMARY
        echo "### Rollback Information" >> $$GITHUB_STEP_SUMMARY
        echo "- **Environment**: $${{ inputs.environment }}" >> $$GITHUB_STEP_SUMMARY
        echo "- **Type**: $${{ inputs.rollback_type }}" >> $$GITHUB_STEP_SUMMARY
        echo "- **Target Commit**: $${{ steps.rollback_target.outputs.rollback_commit }}" >> $$GITHUB_STEP_SUMMARY
        echo "- **Status**: $${{ job.status }}" >> $$GITHUB_STEP_SUMMARY
        echo "" >> $$GITHUB_STEP_SUMMARY
        
        if [ "$${{ job.status }}" == "success" ]; then
          echo "### ✅ Rollback Successful" >> $$GITHUB_STEP_SUMMARY
          echo "" >> $$GITHUB_STEP_SUMMARY
          echo "The $${{ inputs.environment }} environment has been rolled back successfully." >> $$GITHUB_STEP_SUMMARY
          echo "An issue has been created to track this rollback." >> $$GITHUB_STEP_SUMMARY
        else
          echo "### ❌ Rollback Failed" >> $$GITHUB_STEP_SUMMARY
          echo "" >> $$GITHUB_STEP_SUMMARY
          echo "The rollback encountered errors. Manual intervention may be required." >> $$GITHUB_STEP_SUMMARY
        fi
EOT

  commit_message = "Add rollback workflow for detection rules"
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

# Quick rollback workflow - triggered on deployment failure
resource "github_repository_file" "auto_rollback_workflow" {
  repository = data.github_repository.detection_rules.name
  branch     = "main"
  file       = ".github/workflows/auto-rollback.yml"

  content = <<-EOT
name: Auto Rollback on Failure

on:
  workflow_run:
    workflows: ["Deploy Custom Rules to Production"]
    types: [completed]

jobs:
  check-and-rollback:
    if: $${{ github.event.workflow_run.conclusion == 'failure' }}
    runs-on: ubuntu-latest
    name: Automatic Rollback on Production Failure
    
    steps:
    - name: Checkout repository
      uses: actions/checkout@v4
      with:
        fetch-depth: 0

    - name: Get previous successful commit
      id: get_previous
      run: |
        # Find the last successful production deployment
        # This is simplified - in production you'd query workflow runs via API
        PREVIOUS_COMMIT=$(git log --skip=1 -n 1 --pretty=format:"%H" -- custom-rules/)
        echo "previous_commit=$${PREVIOUS_COMMIT}" >> $$GITHUB_OUTPUT
        echo "Will rollback to: $${PREVIOUS_COMMIT}"

    - name: Trigger rollback workflow
      env:
        GH_TOKEN: $${{ secrets.GH_PAT }}
      run: |
        echo "Triggering automatic rollback due to production deployment failure..."
        
        # Trigger the rollback workflow
        gh workflow run rollback-rules.yml \
          -f environment=production \
          -f rollback_type=specific_commit \
          -f commit_sha=$${{ steps.get_previous.outputs.previous_commit }}
        
        # Create high-priority issue
        gh issue create \
          --title "🚨 URGENT: Production deployment failed - Auto rollback initiated" \
          --body "## Automatic Rollback Triggered
        
        ### Alert
        The production deployment has failed and an automatic rollback has been initiated.
        
        ### Failed Deployment
        - **Workflow Run**: [View Failed Run]($${{ github.event.workflow_run.html_url }})
        - **Failed Commit**: $${{ github.event.workflow_run.head_sha }}
        
        ### Rollback Details
        - **Rolling back to**: $${{ steps.get_previous.outputs.previous_commit }}
        - **Time**: $$(date -u '+%Y-%m-%d %H:%M:%S UTC')
        
        ### Immediate Action Required
        1. Check the rollback workflow status
        2. Verify production environment stability
        3. Investigate the deployment failure
        4. Fix the issue before attempting re-deployment
        
        ---
        *This is an automated alert. Please respond immediately.*" \
          --label "urgent,production,rollback,incident"
EOT

  commit_message = "Add automatic rollback workflow for production failures"
  commit_author  = "Terraform"
  commit_email   = "terraform@${var.repo_name_prefix}.local"

  lifecycle {
    ignore_changes = [commit_message, commit_author, commit_email]
  }

  depends_on = [
    null_resource.clone_repository,
    data.github_repository.detection_rules,
    github_repository_file.rollback_workflow
  ]
}

# Output rollback workflow information
output "rollback_workflows" {
  value = {
    manual_rollback = github_repository_file.rollback_workflow.file
    auto_rollback   = github_repository_file.auto_rollback_workflow.file
  }
  description = "Rollback workflow file paths"
}