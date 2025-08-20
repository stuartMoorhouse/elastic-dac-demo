locals {
  repo_name = "${var.repo_name_prefix}-detection-rules"
}

# GitHub owner is now defined as a variable instead of using external data source

resource "null_resource" "create_fork" {
  provisioner "local-exec" {
    command = <<-EOT
      set -e
      echo "Creating fork of elastic/detection-rules as ${local.repo_name}..."
      
      GITHUB_USER="${var.github_owner}"
      
      if gh repo view "$${GITHUB_USER}/${local.repo_name}" &>/dev/null; then
        echo "Repository ${local.repo_name} already exists"
      else
        echo "Forking elastic/detection-rules..."
        gh repo fork elastic/detection-rules --fork-name="${local.repo_name}" --clone=false
        echo "Fork created successfully as ${local.repo_name}"
      fi
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      set -e
      echo "Cleaning up GitHub repository ${self.triggers.repo_name}..."
      
      GITHUB_USER="$(gh api user --jq '.login')"
      
      if gh repo view "$${GITHUB_USER}/${self.triggers.repo_name}" &>/dev/null; then
        echo "Deleting repository ${self.triggers.repo_name}..."
        gh repo delete "$${GITHUB_USER}/${self.triggers.repo_name}" --yes
        echo "Repository deleted successfully"
      else
        echo "Repository ${self.triggers.repo_name} does not exist, skipping deletion"
      fi
    EOT
  }

  triggers = {
    repo_name = local.repo_name
  }
}

# Clean up unnecessary branches from the fork
# This removes all branches from elastic/detection-rules except main to keep the fork clean
# The original repo has 200+ branches that aren't needed for the demo
resource "null_resource" "cleanup_fork_branches" {
  depends_on = [null_resource.create_fork]

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      echo "Cleaning up unnecessary branches from fork..."
      echo "The original elastic/detection-rules has 200+ branches we don't need..."
      
      GITHUB_USER="${var.github_owner}"
      REPO_NAME="${local.repo_name}"
      
      # Wait for fork to be fully ready
      sleep 10
      
      echo "Fetching all branches from fork..."
      # Count total branches first
      TOTAL_BRANCHES=$(gh api repos/$${GITHUB_USER}/$${REPO_NAME}/branches --paginate | jq -r '.[].name' | wc -l)
      echo "Found $${TOTAL_BRANCHES} branches in fork"
      
      # Delete all branches except main using GitHub API
      gh api repos/$${GITHUB_USER}/$${REPO_NAME}/branches --paginate | \
        jq -r '.[].name' | \
        grep -v "^main$" | \
        while read branch; do
          echo "Deleting branch: $${branch}"
          gh api -X DELETE "repos/$${GITHUB_USER}/$${REPO_NAME}/git/refs/heads/$${branch}" 2>/dev/null || true
        done
      
      echo "Branch cleanup complete. Only 'main' branch remains."
      echo "This keeps your fork clean and focused on the demo workflow."
    EOT
  }

  triggers = {
    repo_name = local.repo_name
  }
}

# Enable GitHub Actions and Issues on the forked repository
resource "null_resource" "enable_github_features" {
  depends_on = [
    null_resource.create_fork,
    null_resource.cleanup_fork_branches
  ]

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      echo "Configuring GitHub repository features..."
      
      # Wait a moment for the fork to be fully ready
      sleep 5
      
      # Enable GitHub Actions using gh CLI
      echo "Enabling GitHub Actions..."
      gh api repos/${var.github_owner}/${local.repo_name}/actions/permissions \
        -X PUT \
        -H "Accept: application/vnd.github.v3+json" \
        --input - << 'EOF'
      {
        "enabled": true,
        "allowed_actions": "all"
      }
      EOF
      
      # Enable Issues
      echo "Enabling GitHub Issues..."
      gh api repos/${var.github_owner}/${local.repo_name} \
        -X PATCH \
        -f has_issues=true
      
      echo "GitHub features enabled successfully!"
    EOT
  }

  triggers = {
    repo_name = local.repo_name
    timestamp = timestamp()
  }
}

# Add detection team lead as a collaborator with write access
resource "github_repository_collaborator" "detection_team_lead" {
  repository = local.repo_name
  username   = var.detection_team_lead_username
  permission = "write"  # Allows PR approvals but not admin access

  depends_on = [
    null_resource.create_fork,
    data.github_repository.detection_rules
  ]
}

resource "null_resource" "clone_repository" {
  depends_on = [
    null_resource.create_fork,
    null_resource.cleanup_fork_branches
  ]

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      REPO_NAME="${local.repo_name}"
      TARGET_DIR="../../$${REPO_NAME}"
      GITHUB_USER="${var.github_owner}"
      
      if [ ! -d "$${TARGET_DIR}" ]; then
        echo "Waiting for fork to be available..."
        sleep 5
        
        echo "Cloning repository to $${TARGET_DIR}..."
        git clone "https://github.com/$${GITHUB_USER}/$${REPO_NAME}.git" "$${TARGET_DIR}"
        
        cd "$${TARGET_DIR}"
        
        echo "NOT adding upstream remote - keeping fork independent..."
        # We intentionally do not add upstream remote to keep the fork independent
        
        echo "Creating custom content directory structure..."
        CUSTOM_DIR="${var.repo_name_prefix}"
        mkdir -p "$${CUSTOM_DIR}/rules" "$${CUSTOM_DIR}/docs" "$${CUSTOM_DIR}/workflows"
        
        echo "Creating README for custom content..."
        cat > "$${CUSTOM_DIR}/README.md" << 'README'
# ${var.repo_name_prefix} - Custom Detection Rules and Workflows

This directory contains all customizations specific to this fork of elastic/detection-rules.

## Directory Structure

\`\`\`
${var.repo_name_prefix}/
├── rules/          # Your custom detection rules go here
├── workflows/      # Custom CI/CD workflows documentation
├── docs/          # Documentation for custom rules and processes
└── README.md      # This file
\`\`\`

## Testing Custom Rules

\`\`\`bash
# Validate custom rules
python -m detection_rules validate --rules-dir ${var.repo_name_prefix}/rules/

# Test custom rules
python -m detection_rules test ${var.repo_name_prefix}/rules/
\`\`\`
README
        
        echo "Creating CUSTOM-CONTENT.md guide..."
        cat > "CUSTOM-CONTENT.md" << 'GUIDE'
# Custom Content Guide

This fork includes custom content not present in the original elastic/detection-rules repository.

## Quick Reference - What's Custom?

### Custom Additions:
\`\`\`
├── ${var.repo_name_prefix}/         ← CUSTOM: All custom content
│   ├── rules/                   ← CUSTOM: Your detection rules
│   ├── workflows/               ← CUSTOM: Workflow documentation  
│   └── docs/                    ← CUSTOM: Custom documentation
│
└── CUSTOM-CONTENT.md            ← CUSTOM: This file
\`\`\`

### Everything Else:
All other files and directories are from the original Elastic detection-rules repository.

## How to Add Custom Detection Rules

1. Create your rule in: \`${var.repo_name_prefix}/rules/your-rule.toml\`
2. Test with: \`python -m detection_rules test ${var.repo_name_prefix}/rules/\`
3. Push to dev branch or create PR to main
GUIDE
        
        echo "Committing custom directory structure..."
        git add .
        git commit -m "chore: Initialize custom content directory structure

- Create ${var.repo_name_prefix}/ directory for custom content
- Add subdirectories for rules, docs, and workflows
- Add documentation for custom content management"
        
        echo "Setting up Python virtual environment..."
        python3 -m venv env
        
        echo "Installing dependencies..."
        ./env/bin/pip install --upgrade pip
        ./env/bin/pip install .[dev]
        ./env/bin/pip install lib/kql lib/kibana
        
        echo "Building initial release and creating version lock..."
        ./env/bin/python -m detection_rules dev build-release --update-version-lock
        
        if [ -f "version.lock" ]; then
          echo "Version lock created successfully"
          git add version.lock
          git commit -m "chore: Initialize version.lock for rule versioning
          
          - Create initial version.lock file
          - Ensures consistent rule versions across deployments"
        else
          echo "Note: version.lock not created (may require rules to be present)"
        fi
        
        echo "Creating activation helper script..."
        cat > activate.sh << 'ACTIVATE'
#!/bin/bash
# Helper script to activate the virtual environment
source env/bin/activate
echo "Virtual environment activated. Run 'deactivate' to exit."
ACTIVATE
        chmod +x activate.sh
        
        echo "Repository cloned and configured successfully!"
        echo "To activate the virtual environment, run: cd $${TARGET_DIR} && ./activate.sh"
      else
        echo "Repository already exists at $${TARGET_DIR}"
      fi
    EOT
  }

  triggers = {
    repo_name = local.repo_name
  }
}# Set up dac-demo directory structure in the forked repository

resource "null_resource" "setup_dac_demo_rules" {
  depends_on = [
    null_resource.clone_repository,
    data.github_repository.detection_rules # Repository must be accessible
  ]

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      
      REPO_NAME="${local.repo_name}"
      REPO_DIR="../../$${REPO_NAME}"
      GITHUB_USER="${var.github_owner}"
      
      if [ -d "$${REPO_DIR}" ]; then
        cd "$${REPO_DIR}"
        
        echo "Setting up dac-demo directory structure for custom rules..."
        
        # Create dac-demo directory structure - this is what GitHub Actions use
        mkdir -p dac-demo/rules dac-demo/docs
        
        # Create README for dac-demo
        cat > dac-demo/README.md << 'README'
# DAC Demo - Custom Detection Rules

This directory contains custom detection rules for the Detection as Code demo.

## Directory Structure

```
dac-demo/
├── rules/          # Your custom detection rules (TOML format)
├── docs/           # Documentation for custom rules
└── README.md       # This file
```

## Adding Custom Rules

1. Create your detection rule in TOML format in the `rules/` directory
2. Follow the standard detection-rules schema
3. Test your rules locally before committing

## Testing Custom Rules Locally

```bash
# Set up environment
cd dac-demo-detection-rules
source env/bin/activate

# Export rules from Kibana
python -m detection_rules kibana --space default export-rules \
  --directory dac-demo/rules/ --custom-rules-only --strip-version

# Validate custom rules (if needed)
python -m detection_rules validate-rule dac-demo/rules/*.toml
```

## Deployment Workflow

### Feature Branch → Development
1. Create a feature branch: `git checkout -b feature/your-rule-name`
2. Add your rule to `dac-demo/rules/`
3. Push to GitHub: `git push origin feature/your-rule-name`
4. GitHub Actions automatically creates PR and deploys to Development

### Main Branch → Production
1. Create a Pull Request from dev to main
2. After PR approval and merge, GitHub Actions deploys to Production

## Rule Template

```toml
[metadata]
creation_date = "$(date -u +%Y/%m/%d)"
maturity = "development"
updated_date = "$(date -u +%Y/%m/%d)"

[rule]
author = ["Your Organization"]
description = """
Description of what this rule detects
"""
from = "now-6m"
index = ["logs-*", "filebeat-*"]
language = "kuery"
license = "Elastic License v2"
name = "Your Rule Name"
risk_score = 47
rule_id = "unique-uuid-here"
severity = "medium"
tags = ["Custom", "Your-Tags"]
timestamp_override = "event.ingested"
type = "query"

query = '''
your.query: here
'''

[[rule.threat]]
framework = "MITRE ATT&CK"
[[rule.threat.technique]]
id = "T1059"
name = "Command and Scripting Interpreter"
reference = "https://attack.mitre.org/techniques/T1059/"
```
README
        
        # Create .gitignore for dac-demo
        cat > dac-demo/.gitignore << 'GITIGNORE'
# Temporary files
*.tmp
*.bak
*~

# Python
__pycache__/
*.py[cod]
*$py.class

# Testing
.pytest_cache/
.coverage

# IDE
.vscode/
.idea/
*.swp
*.swo
GITIGNORE
        
        # Commit the dac-demo structure
        git add dac-demo/
        git commit -m "feat: Initialize dac-demo directory structure

- Add dac-demo directory for organization-specific detection rules
- This is the directory used by GitHub Actions workflows
- Add documentation and templates for custom rule development" || echo "dac-demo already committed"
        
        # Push to origin
        git push origin main || echo "Failed to push, may need manual intervention"
        
        echo "dac-demo directory structure created successfully!"
        
        # Create dev branch if it doesn't exist
        if ! git show-ref --verify --quiet refs/heads/dev; then
          echo "Creating dev branch..."
          git checkout -b dev
          git push -u origin dev
          git checkout main
        fi
        
      else
        echo "Repository directory not found at $${REPO_DIR}"
        exit 1
      fi
    EOT
  }

  triggers = {
    repo_name = local.repo_name
    timestamp = timestamp()
  }
}

# Output information about custom rules setup
output "custom_rules_info" {
  value = {
    repository        = "${var.github_owner}/${local.repo_name}"
    custom_rules_path = "dac-demo/rules/"
    workflows = {
      dev_deployment  = ".github/workflows/deploy-dev-to-development.yml"
      prod_deployment = ".github/workflows/deploy-to-prod.yml"
    }
  }
  description = "Information about the custom rules setup in dac-demo directory"

  depends_on = [null_resource.setup_dac_demo_rules]
}