# Elastic Detection as Code (DAC) Demo Environment

This project sets up a complete Elastic Security Detection as Code demo environment using Terraform, including:
- Three Elastic Cloud instances (local/dev testing, development, production)
- A forked detection-rules repository with CI/CD workflows
- Automated deployment pipelines for detection rules
- GitHub integration for monitoring and deployment

## Prerequisites

### 1. GitHub Personal Access Token with SSO Authorization

Since the Elastic organization requires SAML SSO authorization, you must configure your GitHub token **before** running Terraform:

#### Step 1: Create a GitHub Personal Access Token
1. Go to https://github.com/settings/tokens
2. Click "Generate new token" → "Generate new token (classic)"
3. Select the following scopes:
   - `repo` (full control of private repositories - **required for auto-PR creation**)
   - `workflow` (update GitHub Action workflows)
   - `read:org` (read org and team membership)
   - `write:packages` (optional, for package publishing)
4. Generate the token and copy it
5. **Important**: This token will be used both by Terraform AND as a GitHub Actions secret for automated PR creation

#### Step 2: Authorize Token for Elastic Organization (REQUIRED)
**This step is mandatory for forking the elastic/detection-rules repository:**
1. Go back to https://github.com/settings/tokens
2. Find your newly created token
3. Click "Configure SSO" next to the token
4. Click "Authorize" for the **elastic** organization
5. Complete the SSO authentication process

⚠️ **Important**: Without this authorization, the fork creation will fail with a "Resource protected by organization SAML enforcement" error.

#### Step 3: Save Token for Terraform
You'll add this token to your `terraform.tfvars` file in the setup steps below.

### 2. Elastic Cloud API Key
1. Log in to https://cloud.elastic.co
2. Go to Features → API Keys
3. Create a new API key with deployment management permissions
4. Save this key - you'll add it to your `terraform.tfvars` file in the setup steps below

## Setup Instructions

### 1. Clone this repository
```bash
git clone <this-repo>
cd elastic-dac-demo
```

### 2. Configure Terraform variables
```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```
Edit `terraform.tfvars` and add your credentials:
```hcl
ec_api_key   = "your_elastic_cloud_api_key_here"
github_token = "your_github_token_here"
```

### 3. Initialize Terraform
```bash
terraform init
```

### 4. Deploy everything
```bash
terraform apply --auto-approve
```

This will:
- Create three Elastic Cloud deployments (local, development, and production)
- Fork the elastic/detection-rules repository as `dac-demo-detection-rules`
- Clone the fork locally to `../dac-demo-detection-rules`
- Set up Python virtual environment with all dependencies
- Configure the upstream remote for syncing
- Create a custom content directory structure (`dac-demo/` by default)
- Set up authentication for local development (`.detection-rules-cfg.json`)
- Configure CI/CD workflows with automatic PR creation
- Set up branch protection with required status checks
- Create API keys with minimal permissions for GitHub Actions
- Configure GitHub PAT for automated workflows
- Set up rollback capabilities for emergency recovery
- Initialize version.lock for rule versioning
- Store credentials securely (not in source control)

## Customization

### Repository Name Prefix
You can customize the forked repository name in your `terraform.tfvars` file:
```hcl
repo_name_prefix = "my-custom-prefix"  # Creates: my-custom-prefix-detection-rules
```

This prefix is also used for the custom content directory inside the repository:
- Repository name: `my-custom-prefix-detection-rules`
- Custom directory: `my-custom-prefix/rules/`, `my-custom-prefix/docs/`, etc.

### Elastic Cloud Configuration
The default configuration creates 8GB RAM instances. Modify in `terraform/variables.tf` if needed.

## Outputs

After successful deployment, Terraform will output:
- Elastic Cloud deployment IDs
- Elasticsearch and Kibana endpoints for both environments
- GitHub repository location and URL

To view sensitive outputs (passwords):
```bash
terraform output -json production_elasticsearch_password | jq -r
terraform output -json development_elasticsearch_password | jq -r
terraform output -json local_elasticsearch_password | jq -r
```

API keys and credentials are stored in:
- `terraform/elastic-credentials/` - Local directory with cluster credentials (not in git)
- GitHub Actions Secrets - API keys for CI/CD deployments
- `../dac-demo-detection-rules/.detection-rules-cfg.json` - Local development config

## Troubleshooting

### GitHub SSO Authorization Issues
If you see "Resource protected by organization SAML enforcement" errors:
1. Your token isn't authorized for the Elastic organization
2. Follow the authorization steps above
3. The authorization may expire - re-authorize if needed

### Verifying SSO Authorization
Run this command to check if your token is properly authorized:
```bash
gh api orgs/elastic --silent && echo "✓ Authorized" || echo "✗ Not authorized"
```

## CI/CD Workflow & Governance Model

This implementation follows the **GM1 Governance Model: Git as Single Source of Truth**

### What is GM1?
- **Git is authoritative** - All detection rules MUST originate from Git
- **One-way sync** - Rules flow from Git → Elastic, never the reverse
- **No manual edits in Kibana** - All changes go through pull requests
- **Full audit trail** - Every change is tracked in Git history
- **Rollback via Git** - Recovery uses Git commits, not Elastic exports

### Workflow Overview

```
Feature Branch          Dev Branch              Main Branch
     │                      │                        │
     ├──[Push]──→ ✓        │                        │
     │            ↓         │                        │
     │       Validation     │                        │
     │            ↓         │                        │
     │       Auto-PR────────→                        │
     │                      │                        │
     │                 [Review & Merge]              │
     │                      │                        │
     │                      ├──→ Development         │
     │                      │    Environment         │
     │                      │                        │
     │                      ├──[PR]─────────────────→
     │                      │                        │
     │                      │              [Review & Merge]
     │                      │                        │
     │                      │                        ├──→ Production
     │                      │                        │    Environment
     │                      │                        │
     │                      │                   version.lock
     │                      │                        ↓
     │                      │                    [Commit]
```

### Key Features

- **Automatic PR Creation**: Feature branches automatically create PRs to dev branch after validation
- **Multi-Stage Deployment**: Feature → Dev → Production with proper approval gates
- **Version Locking**: Automatic version management for production deployments
- **Rollback Capabilities**: Both manual and automatic rollback on failures
- **Python Environment**: Pre-configured virtual environment with all dependencies
- **Branch Protection**: Enforced code review and validation checks
- **Audit Trail**: Complete history with GitHub issues for incidents
- **Backup & Recovery**: Automatic backups before any rollback operation

### Deployment Environments

1. **Local Elastic Cloud**
   - For initial rule development and testing
   - Dedicated cloud instance for individual developer testing
   - Pre-configured with `.detection-rules-cfg.json` for easy local testing
   
2. **Development Elastic Cloud**
   - Automatically receives rules from feature branches
   - For integration testing before production
   
3. **Production Elastic Cloud**
   - Receives rules when PRs are merged to main
   - Protected with comprehensive validation checks

### Branch Protection & Merge Strategy

#### Main Branch Protection
- **No direct pushes** - all changes require pull requests
- **Linear history enforced** - commits must be rebased before merge
- **Regular merge commits** (not squash) - preserves full commit history for audit trails
- **Required checks**:
  - `validate-rules` status check must pass
  - 1 review approval required
  - All PR conversations must be resolved
- **Enforced for administrators** - no bypassing protection

#### Why Linear History with Regular Merges?
- **Full audit trail**: Every commit is preserved showing rule evolution
- **Clean history**: Linear progression without merge commit clutter
- **Forensic capability**: Can trace back exact changes for security investigations
- **Compliance**: Complete change history for regulatory requirements

### Workflow Summary

1. **Developer creates rule** in feature branch
2. **Push triggers validation** - automatic syntax and test checks
3. **Auto-PR to dev** if validation passes (no manual PR needed)
4. **Review required** - someone must approve the PR
5. **Merge to dev** deploys to Development environment
6. **Test in Development** with real data
7. **PR from dev to main** for production promotion
8. **Review + validation** required before merge
9. **Merge to main** deploys to Production
10. **Version lock** automatically updated and committed

### Automated Deployment Pipeline

#### Feature Branch → Automatic PR Creation
- Push to `feature/*`, `feat/*`, or `fix/*` branches
- Automatically validates custom rules
- **NEW**: If validation passes, automatically creates PR to `dev` branch
- No manual PR creation needed for the first stage

#### Dev Branch → Development Environment
- PR review and approval required
- Once merged to `dev`, automatically deploys to Development
- Allows testing with real data before production

#### Pull Request to Main → Validation
- Create PR from `dev` branch to `main`
- Automated validation workflow runs:
  - Syntax validation for all rules
  - KQL query validation
  - Duplicate rule ID detection
  - Metadata completeness check
  - Detection rules test suite
- Must pass `validate-rules` status check
- Requires 1 approval and resolved conversations

#### Main Branch → Production
- After PR approval and validation
- **NEW**: Automatically updates version.lock file
- Comprehensive validation before deployment
- Automatic deployment to Production
- Commits version.lock back to main branch
- API key authentication with minimal required permissions

### Rollback Capabilities

The pipeline includes comprehensive rollback features for emergency recovery:

#### Manual Rollback
- Trigger from GitHub Actions UI
- Choose environment (Development or Production)
- Two rollback modes:
  - **Last Known Good**: Automatically finds previous working version
  - **Specific Commit**: Rollback to exact commit SHA
- Creates backup before rollback
- Validates rules before deploying
- Creates GitHub issue for incident tracking
- Stores backup artifacts for 30 days

#### Automatic Rollback
- Triggers automatically when Production deployment fails
- Rolls back to previous commit
- Creates high-priority GitHub issue
- No manual intervention required for initial recovery

#### How to Trigger Manual Rollback
1. Go to Actions tab in GitHub repository
2. Select "Rollback Detection Rules" workflow
3. Click "Run workflow"
4. Select environment and rollback type
5. Monitor progress and check created issue

### Version Lock Strategy

The pipeline implements version locking for production deployments:

- **Before Production Deploy**: Runs `python -m detection_rules dev build-release --update-version-lock`
- **Version Tracking**: Each rule gets a version number that increments on changes
- **Consistency**: Ensures same rule versions across environments
- **Audit Trail**: version.lock file tracks all rule versions in Git history

### Complete Workflow Example

For a detailed step-by-step guide of the entire Detection as Code workflow, see [DAC_WORKFLOW_GUIDE.md](DAC_WORKFLOW_GUIDE.md).

Quick start:
```bash
# 1. Create feature branch
git checkout -b feature/new-detection-rule

# 2. Add custom rule to custom-rules/rules/
cd custom-rules/rules
# Create your .toml rule file

# 3. Test locally against your Local Elastic cluster
# Note: Virtual environment is already set up by Terraform
cd ../dac-demo-detection-rules
./activate.sh  # Activate the Python virtual environment
python -m detection_rules validate-rule custom-rules/rules/*.toml
python -m detection_rules test custom-rules/rules/

# 4. Push to trigger validation and auto-PR
git add .
git commit -m "feat: Add new detection rule"
git push origin feature/new-detection-rule

# 5. Auto-PR is created! Check GitHub for the PR to dev branch
# After dev testing, create PR to main for Production

# 6. If rollback needed
# Go to GitHub Actions → Rollback Detection Rules → Run workflow
```

## Next Steps

After deployment:
1. Access Kibana for both environments using the outputted URLs
2. Configure the Elastic GitHub integration in the production instance
3. Test the DAC workflow by modifying detection rules in the dev branch
4. Create pull requests to promote changes from dev to main

## Clean Up

To destroy all resources:
```bash
cd terraform
terraform destroy
```

Note: This will delete the Elastic Cloud deployments but not the GitHub fork.