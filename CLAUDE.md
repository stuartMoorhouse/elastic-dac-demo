# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## IMPORTANT: Security and Best Practices Requirements

**ALWAYS validate changes against these principles before implementation:**

1. **Security First**: All changes must follow security best practices. NEVER introduce configurations that weaken security posture.

2. **Detection Engineering Best Practices**:
   - Detection rules MUST pass validation before being committed to ANY branch
   - Failed validation checks indicate broken rules that create security blind spots
   - Enforce validation checks on all protected branches (main, dev, etc.)
   - No bypassing of security controls, even for administrators

3. **CI/CD Best Practices**:
   - Validation must occur and pass BEFORE code is merged
   - Broken builds should block deployment/merge
   - Fast feedback loops with pre-commit hooks where applicable
   - Clear separation between development and production environments

4. **Infrastructure as Code Best Practices**:
   - No hardcoded secrets or credentials
   - Use proper secret management (terraform.tfvars for local, never .env files in production)
   - Validate all Terraform changes with `terraform plan` before apply
   - Document security implications of infrastructure changes

**⚠️ ALERT: If any requested change violates these best practices, you MUST:**
- Warn the user immediately
- Explain the security/operational risk
- Suggest the best practice alternative
- Only proceed with unsafe changes if explicitly confirmed after warning

## Project Overview

This is an Elastic Security Detection as Code (DAC) demo environment for testing and demonstrating Elastic's detection-rules workflow. The project uses Terraform to provision Elastic Cloud instances and configure GitHub integration for security detection management.

## Architecture

### Infrastructure Components
- **Elastic Cloud Instances**: Two 8GB RAM instances on GCP (Finland region)
  - `elastic-cloud-production`: Production environment with GitHub integration monitoring
  - `elastic-cloud-development`: Development environment for testing detection rules
- **GitHub Repository**: Fork of elastic/detection-rules for DAC workflow
- **Terraform Configuration**: Infrastructure as Code for all resource provisioning

### Key Integrations
- Elastic Cloud API via Terraform provider (`elastic/ec`)
- GitHub API for repository management and integration
- Elastic GitHub integration for monitoring detection-rules repository

## Development Commands

### Terraform Commands
```bash
# Initialize Terraform
terraform init

# Plan infrastructure changes
terraform plan

# Apply infrastructure changes
terraform apply

# Destroy infrastructure (use with caution)
terraform destroy

# Format Terraform files
terraform fmt -recursive

# Validate Terraform configuration
terraform validate
```

### Detection Rules Commands
```bash
# Clone detection-rules fork locally
git clone https://github.com/<your-username>/detection-rules.git

# Run detection-rules tests
cd detection-rules
python -m detection_rules test

# Validate detection rules
python -m detection_rules validate

# Export rules to Elastic
python -m detection_rules kibana export

# Import rules from Elastic
python -m detection_rules kibana import
```

### Environment Setup
```bash
# Install Python dependencies for detection-rules
pip install -r detection-rules/requirements.txt

# Set up pre-commit hooks
pre-commit install

# Run security checks
uv run bandit -r src/
uv run safety check
```

## Configuration Management

### Environment Variables
Required environment variables in `.env`:
```bash
# Elastic Cloud credentials
ELASTIC_CLOUD_API_KEY=<your-elastic-cloud-api-key>
EC_API_KEY=<your-elastic-cloud-api-key>

# GitHub credentials
GITHUB_TOKEN=<your-github-personal-access-token>
GITHUB_OWNER=<your-github-username>

# Elastic instance credentials (generated after deployment)
ELASTIC_CLOUD_PRODUCTION_URL=<production-instance-url>
ELASTIC_CLOUD_PRODUCTION_USERNAME=elastic
ELASTIC_CLOUD_PRODUCTION_PASSWORD=<generated-password>

ELASTIC_CLOUD_DEVELOPMENT_URL=<development-instance-url>
ELASTIC_CLOUD_DEVELOPMENT_USERNAME=elastic
ELASTIC_CLOUD_DEVELOPMENT_PASSWORD=<generated-password>
```

### Terraform Variables
Key Terraform variables to configure:
- `region`: GCP region (default: "gcp-europe-north1")
- `deployment_template`: Elastic deployment template ID
- `elastic_version`: Elasticsearch version to deploy
- `github_repo_name`: Name of the detection-rules fork

## Project Structure

```
elastic-dac-demo/
├── terraform/                  # Terraform configuration files
│   ├── main.tf                # Main infrastructure definition
│   ├── variables.tf           # Variable declarations
│   ├── outputs.tf             # Output values
│   └── providers.tf           # Provider configuration
├── scripts/                   # Automation scripts
│   ├── setup_github.sh        # GitHub repository setup
│   ├── configure_elastic.sh   # Elastic instance configuration
│   └── deploy_rules.sh        # Detection rules deployment
├── detection-rules/           # Local clone of detection-rules fork
├── .env                       # Environment variables (not in git)
└── .terraform/                # Terraform state (not in git)
```

## Critical Workflows

### Initial Setup Workflow
1. Configure environment variables in `.env`
2. Initialize Terraform: `terraform init`
3. Deploy infrastructure: `terraform apply`
4. Fork and clone detection-rules repository
5. Configure Elastic GitHub integration
6. Test detection rules CI/CD pipeline

### Detection Rules Development Workflow
1. Create feature branch in detection-rules fork
2. Develop and test detection rules locally
3. Push changes to GitHub
4. CI validates rules against development instance
5. Merge to main branch
6. Production instance syncs rules via GitHub integration

### Troubleshooting Commands
```bash
# Check Elastic Cloud instance status
curl -H "Authorization: ApiKey $EC_API_KEY" \
  https://api.elastic-cloud.com/api/v1/deployments

# Test Elasticsearch connectivity
curl -u elastic:$ELASTIC_CLOUD_PRODUCTION_PASSWORD \
  $ELASTIC_CLOUD_PRODUCTION_URL/_cluster/health

# Verify GitHub integration
gh api repos/$GITHUB_OWNER/detection-rules
```

## Security Considerations

- Store all credentials in environment variables, never hardcode
- Use Terraform state encryption for sensitive infrastructure data
- Implement least-privilege access for GitHub and Elastic Cloud APIs
- Regularly rotate API keys and passwords
- Monitor Elastic Cloud audit logs for security events

## Success Validation

Verify the setup is working correctly:
1. **CI Integration**: Detection-rules CI can connect to both Elastic instances
2. **GitHub Sync**: Production instance receives logs from GitHub
3. **Local Development**: Local clone can push to GitHub and trigger CI
4. **Rule Deployment**: Changes in GitHub reflect in production Elastic instance

## Custom Claude Commands

- `/security-review` - Analyze Terraform and detection rules for security issues
- `/fix-github-issue <number>` - Automate fixes for GitHub issues in detection-rules

## Important Notes

- Always run `terraform plan` before `terraform apply` to review changes
- Keep Terraform state files secure and never commit them to git
- Test detection rules in development before promoting to production
- Use GitHub branch protection rules to prevent direct pushes to main
- Document all custom detection rules with clear descriptions and references
- Do not add verbose comments to Terraform files - keep them concise and clean