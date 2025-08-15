# Elastic Detection as Code (DAC) Demo Environment

This project sets up a complete Elastic Security Detection as Code demo environment using Terraform, including:
- Two Elastic Cloud instances (production and development)
- A forked detection-rules repository with custom naming
- GitHub integration for monitoring detection rules

## Prerequisites

### 1. GitHub Personal Access Token with SSO Authorization

Since the Elastic organization requires SAML SSO authorization, you must configure your GitHub token **before** running Terraform:

#### Step 1: Create a GitHub Personal Access Token
1. Go to https://github.com/settings/tokens
2. Click "Generate new token" → "Generate new token (classic)"
3. Select the following scopes:
   - `repo` (full control of private repositories)
   - `workflow` (update GitHub Action workflows)
   - `read:org` (read org and team membership)
4. Generate the token and copy it

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
- Create two Elastic Cloud deployments (production and development)
- Fork the elastic/detection-rules repository as `dac-demo-detection-rules`
- Clone the fork locally to `../dac-demo-detection-rules`
- Configure the upstream remote for syncing
- Create a custom content directory structure (`dac-demo/` by default)
- Add documentation for managing custom detection rules

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
```

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

## CI/CD Workflow

The repository includes automated CI/CD workflows and branch protection:

### Branch Strategy
- **main branch**: Protected, requires pull requests and passing CI checks
  - Requires 1 code review approval
  - Must pass "Lint Detection Rules" and "Rule Format Validation" checks
  - No direct pushes allowed (enforced for admins)
  
- **dev branch**: Development branch with relaxed rules
  - Direct pushes allowed for rapid development
  - Only requires basic lint check to pass
  - No review requirements

### CI Pipeline
The GitHub Actions workflow automatically runs:
1. **Lint Detection Rules**: Validates detection rule syntax
2. **Rule Format Validation**: Checks TOML format compliance
3. **Basic Security Scan**: Scans for potential secrets in rules
4. **Basic Lint** (dev only): Quick syntax check for dev branch

### Working with the Repository
```bash
# For development work
git checkout dev
# Make changes and push directly
git push origin dev

# For production changes
git checkout -b feature/my-feature
# Make changes
git push origin feature/my-feature
# Create pull request to main branch
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