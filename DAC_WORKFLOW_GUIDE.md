# Detection as Code (DAC) Workflow Guide

This guide demonstrates the complete CI/CD workflow for Elastic Security detection rules using the infrastructure created by this demo.

## Infrastructure Overview

The demo creates three Elastic Cloud environments:
1. **Local** - Elastic Cloud instance for initial rule development and testing
2. **Development** - Elastic Cloud instance for integration testing  
3. **Production** - Elastic Cloud instance for production rules

## Complete Workflow Demonstration

### Step 1: Local Development

Start with the local Elastic Cloud instance for initial rule development:

```bash
# Navigate to terraform directory
cd terraform

# Deploy the infrastructure (creates three Elastic Cloud instances)
terraform apply --auto-approve

# Get local instance credentials
terraform output local_kibana_endpoint
terraform output -json local_elasticsearch_password | jq -r

# Access local Kibana (URL from terraform output)
# Username: elastic
# Password: (from terraform output)
```

### Step 2: Create a Feature Branch

```bash
# Navigate to the cloned detection-rules repository
cd ../../dac-demo-detection-rules

# Create a feature branch for your new rule
git checkout -b feature/suspicious-powershell-detection

# Navigate to custom rules directory
cd custom-rules/rules
```

### Step 3: Develop Your Detection Rule

Create a new detection rule in TOML format:

```bash
# Create your rule file
cat > suspicious-powershell-encoding.toml << 'EOF'
[metadata]
creation_date = "2024/01/17"
maturity = "production"
updated_date = "2024/01/17"

[rule]
author = ["Security Team"]
description = """
Detects PowerShell commands using encoding, which is often used by attackers
to obfuscate malicious commands.
"""
from = "now-6m"
index = ["logs-*", "winlogbeat-*", "logs-windows.*"]
language = "kuery"
license = "Elastic License v2"
name = "Suspicious PowerShell Encoded Command"
risk_score = 65
rule_id = "a1b2c3d4-e5f6-7890-abcd-ef1234567890"
severity = "high"
tags = ["Custom", "PowerShell", "Windows", "Defense Evasion"]
timestamp_override = "event.ingested"
type = "query"

query = '''
process.name: "powershell.exe" and 
process.args: ("-enc" or "-encodedcommand" or "-e") and
not user.name: ("SYSTEM" or "LOCAL SERVICE")
'''

[[rule.threat]]
framework = "MITRE ATT&CK"
[[rule.threat.technique]]
id = "T1027"
name = "Obfuscated Files or Information"
reference = "https://attack.mitre.org/techniques/T1027/"

[rule.threat.tactic]
id = "TA0005"
name = "Defense Evasion"
reference = "https://attack.mitre.org/tactics/TA0005/"
EOF
```

### Step 4: Test Locally

```bash
# Return to repository root
cd ../..

# Set up Python environment (if not already done)
python -m pip install --upgrade pip
pip install .
pip install lib/kibana lib/kql

# Validate your custom rule
python -m detection_rules validate-rule custom-rules/rules/suspicious-powershell-encoding.toml

# Run tests on custom rules
python -m detection_rules test custom-rules/rules/

# Test deployment to local Elastic Cloud Kibana
export KIBANA_URL=$(terraform -chdir=../elastic-dac-demo/terraform output -raw local_kibana_endpoint)
export KIBANA_USERNAME=elastic
export KIBANA_PASSWORD=$(terraform -chdir=../elastic-dac-demo/terraform output -json local_elasticsearch_password | jq -r)

python -m detection_rules kibana import-rules \
  -d custom-rules/rules/ \
  --kibana-url "$KIBANA_URL" \
  --kibana-user "$KIBANA_USERNAME" \
  --kibana-password "$KIBANA_PASSWORD"
```

### Step 5: Push to Feature Branch (Triggers Dev Deployment)

```bash
# Add and commit your changes
git add custom-rules/rules/suspicious-powershell-encoding.toml
git commit -m "feat: Add suspicious PowerShell encoding detection rule"

# Push to feature branch
git push origin feature/suspicious-powershell-detection
```

**Automated Actions:**
- GitHub Actions workflow `deploy-to-dev.yml` triggers
- Rule validation runs
- If validation passes, rule deploys to Development Elastic Cloud instance
- Check the Actions tab on GitHub to monitor deployment

### Step 6: Verify in Development Environment

```bash
# Get Development environment credentials from Terraform
cd ../elastic-dac-demo/terraform
terraform output development_kibana_endpoint
terraform output development_elasticsearch_password

# Access Development Kibana and verify rule deployment
```

### Step 7: Create Pull Request

```bash
# Create PR using GitHub CLI
gh pr create \
  --title "Add suspicious PowerShell encoding detection" \
  --body "This rule detects potentially malicious PowerShell commands using encoding to obfuscate their payload." \
  --label "detection-rule"

# Or create PR via GitHub web interface
```

**PR Workflow:**
1. Automated validation checks run
2. Team reviews the rule
3. Require at least 1 approval before merge

### Step 8: Merge to Main (Triggers Production Deployment)

After PR approval:

```bash
# Merge the PR (can be done via GitHub web interface)
gh pr merge --squash

# Or if merging locally:
git checkout main
git pull origin main
git merge --squash feature/suspicious-powershell-detection
git push origin main
```

**Automated Actions:**
- GitHub Actions workflow `deploy-to-prod.yml` triggers
- Comprehensive validation suite runs
- If all checks pass, rule deploys to Production Elastic Cloud instance
- Deployment notification created in GitHub Actions summary

### Step 9: Verify Production Deployment

```bash
# Get Production environment credentials
terraform output production_kibana_endpoint
terraform output production_elasticsearch_password

# Access Production Kibana and verify rule is active
```

### Step 10: Cleanup Feature Branch

```bash
# Delete local feature branch
git branch -d feature/suspicious-powershell-detection

# Delete remote feature branch (usually auto-deleted after PR merge)
git push origin --delete feature/suspicious-powershell-detection
```

## Monitoring the CI/CD Pipeline

### GitHub Actions Dashboard
- Navigate to your repository on GitHub
- Click on the "Actions" tab
- Monitor workflow runs for both development and production deployments

### Workflow Status Badges
Add these to your repository README:

```markdown
![Deploy to Dev](https://github.com/<your-username>/dac-demo-detection-rules/actions/workflows/deploy-to-dev.yml/badge.svg)
![Deploy to Prod](https://github.com/<your-username>/dac-demo-detection-rules/actions/workflows/deploy-to-prod.yml/badge.svg)
```

## Troubleshooting

### Common Issues and Solutions

1. **Workflow fails with authentication error**
   - Verify GitHub Secrets are correctly set
   - Check Elastic Cloud credentials haven't expired
   - Ensure Kibana endpoints are accessible

2. **Rule validation fails**
   - Check TOML syntax is correct
   - Ensure all required fields are present
   - Validate KQL query syntax

3. **Elastic Cloud deployment timeout**
   - This is expected - deployments take 4-5 minutes
   - Terraform may timeout after 2 minutes but deployment continues
   - Wait 5 minutes then run `terraform refresh` to update state

4. **GitHub Actions not triggering**
   - Verify workflow files are in `.github/workflows/`
   - Check branch names match workflow triggers
   - Ensure files in `custom-rules/` directory changed

## Best Practices

1. **Always test locally first** - Use local Elastic Cloud instance to validate rules before pushing
2. **Use feature branches** - Never commit directly to main
3. **Write comprehensive rule descriptions** - Help reviewers understand the detection logic
4. **Include MITRE ATT&CK mapping** - Provide threat context
5. **Set appropriate risk scores** - Based on confidence and impact
6. **Test in Development** - Verify rule behavior before production
7. **Monitor for false positives** - Check rule performance in each environment
8. **Document custom rules** - Maintain documentation in `custom-rules/README.md`

## Security Considerations

- Never commit credentials to the repository
- Use GitHub Secrets for all sensitive values
- Rotate Elastic Cloud API keys regularly
- Review GitHub Actions logs for sensitive data exposure
- Implement least-privilege access for CI/CD service accounts

## Success Validation Checklist

- [ ] Three Elastic Cloud instances created and accessible
- [ ] Feature branch push triggers Development deployment
- [ ] PR merge to main triggers Production deployment
- [ ] Custom rules successfully deployed to all environments
- [ ] GitHub Actions workflows complete successfully
- [ ] Kibana shows deployed rules as active
- [ ] Audit trail available in GitHub Actions history