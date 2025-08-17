# Set up custom-rules directory structure in the forked repository

resource "null_resource" "setup_custom_rules" {
  depends_on = [
    null_resource.clone_repository,
    data.github_repository.detection_rules # Repository must be accessible
  ]

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      
      REPO_NAME="${local.repo_name}"
      REPO_DIR="../../$${REPO_NAME}"
      GITHUB_USER="${data.external.github_user.result.login}"
      
      if [ -d "$${REPO_DIR}" ]; then
        cd "$${REPO_DIR}"
        
        echo "Setting up custom-rules directory structure..."
        
        # Create custom-rules directory structure
        mkdir -p custom-rules/rules
        
        # Create custom-rules configuration
        cat > custom-rules/.detection-rules-cfg.json << 'CONFIG'
{
  "name": "custom-rules",
  "custom_rules_dir": "custom-rules/rules"
}
CONFIG
        
        # Create README for custom-rules
        cat > custom-rules/README.md << 'README'
# Custom Detection Rules

This directory contains custom detection rules specific to this organization.

## Directory Structure

```
custom-rules/
├── rules/          # Your custom detection rules (TOML format)
└── README.md       # This file
```

## Adding Custom Rules

1. Create your detection rule in TOML format in the `rules/` directory
2. Follow the standard detection-rules schema
3. Test your rules locally before committing

## Testing Custom Rules Locally

```bash
# Set up environment
export CUSTOM_RULES_DIR=./custom-rules

# Validate custom rules
python -m detection_rules validate-rule custom-rules/rules/*.toml

# Run tests
python -m detection_rules test custom-rules/rules/
```

## Deployment Workflow

### Feature Branch → Development
1. Create a feature branch: `git checkout -b feature/your-rule-name`
2. Add your rule to `custom-rules/rules/`
3. Push to GitHub: `git push origin feature/your-rule-name`
4. GitHub Actions automatically deploys to Development environment

### Main Branch → Production
1. Create a Pull Request from your feature branch to main
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
        
        # Create an example custom rule
        cat > custom-rules/rules/example-suspicious-process.toml << 'RULE'
[metadata]
creation_date = "$(date -u +%Y/%m/%d)"
maturity = "development"
updated_date = "$(date -u +%Y/%m/%d)"

[rule]
author = ["Custom Security Team"]
description = """
Example rule that detects suspicious PowerShell encoding activity.
This is a demonstration rule for the DAC workflow.
"""
from = "now-6m"
index = ["logs-*", "winlogbeat-*", "logs-windows.*"]
language = "kuery"
license = "Elastic License v2"
name = "Example - Suspicious PowerShell Encoding"
risk_score = 47
rule_id = "$(uuidgen | tr '[:upper:]' '[:lower:]')"
severity = "medium"
tags = ["Custom", "PowerShell", "Windows", "Example"]
timestamp_override = "event.ingested"
type = "query"

query = '''
process.name: "powershell.exe" and process.args: ("-enc" or "-encodedcommand")
'''

[[rule.threat]]
framework = "MITRE ATT&CK"
[[rule.threat.technique]]
id = "T1059"
name = "Command and Scripting Interpreter"
reference = "https://attack.mitre.org/techniques/T1059/"
[[rule.threat.technique.subtechnique]]
id = "T1059.001"
name = "PowerShell"
reference = "https://attack.mitre.org/techniques/T1059/001/"

[rule.threat.tactic]
id = "TA0002"
name = "Execution"
reference = "https://attack.mitre.org/tactics/TA0002/"
RULE
        
        # Create .gitignore for custom-rules
        cat > custom-rules/.gitignore << 'GITIGNORE'
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
        
        # Commit the custom-rules structure
        git add custom-rules/
        git commit -m "feat: Initialize custom-rules directory structure

- Add custom-rules directory for organization-specific detection rules
- Include example detection rule for PowerShell encoding
- Add documentation and templates for custom rule development
- Configure .detection-rules-cfg.json for custom rules management" || echo "Custom rules already committed"
        
        # Push to origin
        git push origin main || echo "Failed to push, may need manual intervention"
        
        echo "Custom-rules directory structure created successfully!"
        
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
    repository        = "${data.external.github_user.result.login}/${local.repo_name}"
    custom_rules_path = "custom-rules/rules/"
    example_rule      = "custom-rules/rules/example-suspicious-process.toml"
    workflows = {
      dev_deployment  = ".github/workflows/deploy-to-dev.yml"
      prod_deployment = ".github/workflows/deploy-to-prod.yml"
    }
  }
  description = "Information about the custom rules setup"

  depends_on = [null_resource.setup_custom_rules]
}