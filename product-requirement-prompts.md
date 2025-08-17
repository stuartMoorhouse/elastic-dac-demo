# Product Requirement Prompts

This file contains the requirements for your project. Fill out each section with relevant details before running `/init` in Claude Code. Claude will use this information to generate your initial project structure and implementation.

## Objective

```
Create a demo environment for testing Elastic Security's Detection as Code functionality.


```

## What

```
Deploy the following resources using Terraform:

- One 8 GB RAM Elastic Cloud instance on GCP, Finland, with the name "elastic-cloud-production"
- One 8 GB RAM Elastic Cloud instance on GCP, Finland, with the name "elastic-cloud-development"
- One 8 GB RAM Elastic Cloud instance on GCP, Finland, with the name "elastic-cloud-local"
- One fork of the Elastic Cloud DAC repo https://github.com/elastic/detection-rules on the user's own GitHub 
- A clone of the DAC repo fork on the local machine 
- An Elastic GitHub integration on elastic-cloud-production that monitors the detection-rules fork


```

## Why

```
To test and demontrate a DAC workflow with Elastic's detection-rules

```

## Success criteria

```
This demo is only concerned with custom rules, so:

Use Git only for custom rules
In the newly create fork of detection-rules on the localmachine:
bash# Set up custom rules directory

python -m detection_rules custom-rules setup-config custom-rules
export CUSTOM_RULES_DIR=./custom-rules

## configure authentication from the users machine to the local cluster
Create a file in the root
of the repo called
.detection-rules-cfg.json
2. add the URL of the Local Elastic Cloud cluster to .env
3. Create and add an API key for the Local Elastic Cloud cluster to .env

# Your repo structure:
detection-rules/
├── custom-rules/
│   └── rules/        # ONLY your custom rules here
├── .github/
│   └── workflows/    # CI/CD for custom rules only

In your CI/CD workflow:
yaml- name: Deploy Custom Rules Only
  run: |
    # This imports ONLY from custom-rules directory
    python -m detection_rules kibana import-rules \
      -d custom-rules/rules/ \
      --cloud-id ${{ secrets.CLOUD_ID }}


And I want to be able to demonstrate this workflow using the resources created here: 

## Elastic Security SIEM - Full CI/CD Pipeline
1. Local Development
bash
# Setup and create feature branch
git clone https://github.com/[your-org]/detection-rules.git
cd detection-rules
git checkout -b feature/suspicious-powershell-detection
Develop rule locally in Kibana:
Open your LOCAL Elastic cluster Kibana UI
Navigate to Security → Rules
Click "Create new rule"
Write KQL query: process.name: "powershell.exe" and process.args: "-enc"
Test rule against sample data
Save and enable the rule
Note the rule ID
Export rule to feature branch:
bash
# Export from local Kibana (creates NDJSON)
python -m detection_rules kibana export-rules \
  --rule-id [RULE_ID] -d exports/

# Convert to TOML in repo (still in feature branch)
python -m detection_rules import-rules-to-repo \
  exports/[RULE_ID].ndjson

# Validate locally
python -m detection_rules validate-rule \
  rules/[directory]/[rule_name].toml

# Run tests locally
python -m detection_rules test
2. Version Control & Dev Deployment
bash
# Still in feature branch, commit changes
git add rules/
git commit -m "feat: Add suspicious PowerShell encoding detection"
git push origin feature/suspicious-powershell-detection
🚀 GitHub Action triggers: Deploy to Development Kibana
Automated validation tests run
Rules deployed to Dev environment for testing
Team can review rule behavior in Dev
3. CI/CD Pipeline - PR to Main
bash
# Create Pull Request to main
gh pr create --title "Add suspicious PowerShell detection" \
  --body "Detects encoded PowerShell commands" \
  --label "detection-rule"
🔍 GitHub Action triggers: PR validation workflow
KQL syntax validation
Schema compliance checks
Unit tests execution
Required peer review (1-2 approvers)
Dev test results attached to PR
4. Production Deployment
bash
# After PR approval, merge to main
git checkout main
git pull origin main
git merge --squash feature/suspicious-powershell-detection
git push origin main
🚀 GitHub Action triggers: Deploy to Production Kibana
Final validation suite runs
Rules deployed to Production Kibana
Deployment notification sent to team
Automatic rollback on failure
5. Cleanup
bash
# Delete local feature branch
git branch -d feature/suspicious-powershell-detection
# Delete remote feature branch (usually auto-deleted after PR merge)
git push origin --delete feature/suspicious-powershell-detection

✅ Best Practices Applied:
Detection Engineering
✅ Test rules in isolated environment first (local → dev → prod)
✅ Version control all detection logic as code
✅ Peer review for quality assurance
✅ Automated validation before deployment
DevOps/CI/CD
✅ Feature branch strategy (not direct commits to main)
✅ Automated testing at multiple stages
✅ Progressive deployment (dev → prod)
✅ Squash merge for clean commit history
✅ Rollback capability on failed deployments
GitHub Best Practices
✅ Protected main branch (no direct pushes)
✅ Required PR reviews before merge
✅ Branch cleanup after merge
✅ Semantic commit messages
✅ PR labels for categorization
Security Considerations
✅ Secrets stored in GitHub Secrets (not in code)
✅ Least privilege access (dev vs prod credentials)
✅ Audit trail via Git history
✅ Automated rollback on validation failure


```

## Documentation and references (Optional)

```
https://github.com/elastic/detection-rules
https://registry.terraform.io/providers/elastic/ec/latest/docs

The secrets for Elastic Cloud and GitHub are in /.env



```
# Simplified CI/CD Best Practices for Detection as Code Demo

## Branch Strategy

### Main Branch (Production)
- Block direct pushes - only allow pull requests
- Require 1 code review before merge
- Require CI tests to pass
- Apply rules to everyone (including admins)

### Feature Branches (Development)
- Allow direct pushes for quick development
- No review requirements
- Basic validation only

## CI/CD Pipeline

### Required Checks
1. Syntax validation (lint detection rules)
2. Basic security scan
3. Rule format validation

## Terraform Implementation for Demo

### What You Need to Create

#### GitHub Provider Setup
- Configure GitHub provider with token authentication
- Set organization and repository name

#### Branch Protection Resources
```
Main branch protection:
- pattern = "main"
- require 1 pull request review
- require status checks: ["ci/lint", "ci/validation"]
- block direct pushes
- enforce for admins

Feature branches protection:
- allow direct pushes
- minimal status checks: ["ci/basic-lint"]
```

#### Repository Configuration
- Create repository with security features
- Set main as default branch
- Enable secret scanning

### Required Variables
- `github_token` (sensitive) - GitHub personal access token
- `github_organization` - Your GitHub username/org
- `repository_name` - Name for the detection rules repo

### Required Outputs
- Repository URL
- Branch protection summary

This simplified approach demonstrates the core concepts without complexity - perfect for showing how Infrastructure as Code can enforce security best practices for Detection as Code repositories.