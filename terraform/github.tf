locals {
  repo_name = "${var.repo_name_prefix}-detection-rules"
}

data "external" "github_user" {
  program = ["bash", "-c", "gh api user --jq '{login:.login}' | jq -c ."]
}

resource "null_resource" "create_fork" {
  provisioner "local-exec" {
    command = <<-EOT
      set -e
      echo "Creating fork of elastic/detection-rules as ${local.repo_name}..."
      
      GITHUB_USER="${data.external.github_user.result.login}"
      
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

resource "null_resource" "clone_repository" {
  depends_on = [null_resource.create_fork]

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      REPO_NAME="${local.repo_name}"
      TARGET_DIR="../../$${REPO_NAME}"
      GITHUB_USER="${data.external.github_user.result.login}"
      
      if [ ! -d "$${TARGET_DIR}" ]; then
        echo "Waiting for fork to be available..."
        sleep 5
        
        echo "Cloning repository to $${TARGET_DIR}..."
        git clone "https://github.com/$${GITHUB_USER}/$${REPO_NAME}.git" "$${TARGET_DIR}"
        
        cd "$${TARGET_DIR}"
        
        echo "Adding upstream remote..."
        git remote add upstream "https://github.com/elastic/detection-rules.git"
        
        echo "Fetching upstream..."
        git fetch upstream
        
        echo "Setting upstream for main branch..."
        git branch --set-upstream-to=upstream/main main
        
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
}