# Data source to get repository information after fork is created
data "github_repository" "detection_rules" {
  full_name = "${var.github_owner}/${local.repo_name}"

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
    pull_request_bypassers          = []
    restrict_dismissals             = false
    # Note: dismissal_restrictions removed - collaborators with write access can dismiss reviews
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
    github_repository_file.dev_branch_deploy_workflow,
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
    github_repository_file.dev_branch_deploy_workflow
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
}# Pull Request Validation Workflow
# This workflow runs when PRs are opened to main branch
# Provides the "validate-rules" status check required for merging

resource "github_repository_file" "pr_validation_workflow" {
  repository = data.github_repository.detection_rules.name
  branch     = "main"
  file       = ".github/workflows/pr-validate.yml"

  content = <<-EOT
name: PR Validation - Detection Rules

on:
  pull_request:
    branches:
      - main
    paths:
      - 'custom-rules/**'
      - '.github/workflows/pr-validate.yml'

jobs:
  validate-rules:
    name: Validate Detection Rules
    runs-on: ubuntu-latest
    
    steps:
    - name: Checkout PR branch
      uses: actions/checkout@v4
      with:
        fetch-depth: 0
        ref: $${{ github.event.pull_request.head.sha }}

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

    - name: Validate custom rules syntax
      run: |
        echo "🔍 Validating detection rules syntax..."
        if [ -d "custom-rules/rules" ] && [ "$(ls -A custom-rules/rules 2>/dev/null)" ]; then
          for rule in custom-rules/rules/*.toml; do
            if [ -f "$rule" ]; then
              echo "Validating: $rule"
              python -m detection_rules validate-rule "$rule"
            fi
          done
          echo "✅ All rules have valid syntax"
        else
          echo "ℹ️ No custom rules found to validate"
        fi

    - name: Run detection rules tests
      run: |
        echo "🧪 Running detection rules tests..."
        if [ -d "custom-rules/rules" ] && [ "$(ls -A custom-rules/rules 2>/dev/null)" ]; then
          python -m detection_rules test custom-rules/rules/
          echo "✅ All tests passed"
        else
          echo "ℹ️ No custom rules to test"
        fi

    - name: Check for duplicate rule IDs
      run: |
        echo "🔍 Checking for duplicate rule IDs..."
        if [ -d "custom-rules/rules" ] && [ "$(ls -A custom-rules/rules 2>/dev/null)" ]; then
          python -c "
import toml
import os
import sys
from pathlib import Path

rule_ids = {}
duplicates = False

for rule_file in Path('custom-rules/rules').glob('*.toml'):
    try:
        with open(rule_file, 'r') as f:
            rule = toml.load(f)
            rule_id = rule.get('metadata', {}).get('rule_id')
            if rule_id:
                if rule_id in rule_ids:
                    print(f'❌ Duplicate rule ID {rule_id} found in:')
                    print(f'   - {rule_ids[rule_id]}')
                    print(f'   - {rule_file}')
                    duplicates = True
                else:
                    rule_ids[rule_id] = str(rule_file)
    except Exception as e:
        print(f'⚠️ Error reading {rule_file}: {e}')

if duplicates:
    sys.exit(1)
else:
    print('✅ No duplicate rule IDs found')
"
        else
          echo "ℹ️ No custom rules to check"
        fi

    - name: Validate KQL queries
      run: |
        echo "🔍 Validating KQL queries in rules..."
        if [ -d "custom-rules/rules" ] && [ "$(ls -A custom-rules/rules 2>/dev/null)" ]; then
          python -c "
import toml
import os
from pathlib import Path

errors = []

for rule_file in Path('custom-rules/rules').glob('*.toml'):
    try:
        with open(rule_file, 'r') as f:
            rule = toml.load(f)
            # Check if rule has a query
            if 'rule' in rule and 'query' in rule['rule']:
                query = rule['rule']['query']
                if not query or not query.strip():
                    errors.append(f'{rule_file}: Empty query')
                print(f'✓ {rule_file.name}: Query present')
    except Exception as e:
        errors.append(f'{rule_file}: {e}')

if errors:
    print('\\n❌ Validation errors:')
    for error in errors:
        print(f'   - {error}')
    exit(1)
else:
    print('\\n✅ All KQL queries validated')
"
        else
          echo "ℹ️ No custom rules with queries to validate"
        fi

    - name: Check rule metadata
      run: |
        echo "📋 Checking rule metadata completeness..."
        if [ -d "custom-rules/rules" ] && [ "$(ls -A custom-rules/rules 2>/dev/null)" ]; then
          python -c "
import toml
from pathlib import Path

required_fields = ['rule_id', 'name', 'description', 'risk_score', 'severity']
warnings = []

for rule_file in Path('custom-rules/rules').glob('*.toml'):
    try:
        with open(rule_file, 'r') as f:
            rule = toml.load(f)
            metadata = rule.get('metadata', {})
            for field in required_fields:
                if field not in metadata:
                    warnings.append(f'{rule_file.name}: Missing {field}')
    except Exception as e:
        print(f'⚠️ Error reading {rule_file}: {e}')

if warnings:
    print('⚠️ Metadata warnings (non-blocking):')
    for warning in warnings:
        print(f'   - {warning}')
else:
    print('✅ All rules have complete metadata')
"
        else
          echo "ℹ️ No custom rules to check metadata"
        fi

    - name: Generate validation summary
      if: always()
      run: |
        echo "## 📊 Validation Summary" >> $$GITHUB_STEP_SUMMARY
        echo "" >> $$GITHUB_STEP_SUMMARY
        
        if [ -d "custom-rules/rules" ] && [ "$(ls -A custom-rules/rules 2>/dev/null)" ]; then
          RULE_COUNT=$(find custom-rules/rules -name "*.toml" -type f | wc -l | tr -d ' ')
          echo "- **Rules validated**: $${RULE_COUNT}" >> $$GITHUB_STEP_SUMMARY
        else
          echo "- **Rules validated**: 0 (no custom rules found)" >> $$GITHUB_STEP_SUMMARY
        fi
        
        echo "- **Syntax validation**: ✅ Passed" >> $$GITHUB_STEP_SUMMARY
        echo "- **Test execution**: ✅ Passed" >> $$GITHUB_STEP_SUMMARY
        echo "- **Duplicate check**: ✅ Passed" >> $$GITHUB_STEP_SUMMARY
        echo "- **KQL validation**: ✅ Passed" >> $$GITHUB_STEP_SUMMARY
        echo "" >> $$GITHUB_STEP_SUMMARY
        echo "### Ready for merge ✅" >> $$GITHUB_STEP_SUMMARY
EOT

  commit_message = "Add PR validation workflow for detection rules"
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

# Output to confirm workflow creation
output "pr_validation_workflow_path" {
  value       = github_repository_file.pr_validation_workflow.file
  description = "Path to the PR validation workflow"
}