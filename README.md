# Elastic Detection as Code (DAC) Demo Environment

This project sets up a complete Elastic Security Detection as Code demo environment using Terraform, including:
- Two Elastic Cloud instances (production and development)
- A forked detection-rules repository with custom naming
- GitHub integration for monitoring detection rules

## Important Considerations

### Terraform State Management
This configuration generates Elastic Cloud passwords that are stored in Terraform state. As with any Terraform project containing sensitive outputs, consider using a remote backend with encryption (S3, Terraform Cloud, etc.) rather than local state files. See the [Terraform Backend Configuration](#terraform-backend-configuration) section for setup options.

Note: If you're using Fleet integrations with this setup, be aware of potential configuration drift issues with secrets (see [elastic/terraform-provider-elasticstack#689](https://github.com/elastic/terraform-provider-elasticstack/issues/689)).

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

#### Step 3: Add Token to Environment
Add your token to the `.env` file:
```bash
GITHUB_TOKEN=ghp_your_token_here
```

### 2. Elastic Cloud API Key
1. Log in to https://cloud.elastic.co
2. Go to Features → API Keys
3. Create a new API key with deployment management permissions
4. Add to `.env` file:
```bash
EC_API_KEY=your_elastic_cloud_api_key_here
```

## Setup Instructions

### 1. Clone this repository
```bash
git clone <this-repo>
cd elastic-dac-demo
```

### 2. Configure environment variables
```bash
cp .env-example .env
```
Edit `.env` and add your credentials:
- `EC_API_KEY=your_elastic_cloud_api_key_here`
- `GITHUB_TOKEN=your_github_token_here`

### 3. Initialize Terraform
```bash
cd terraform
export $(grep -v '^#' ../.env | xargs)
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

## Customization

### Repository Name Prefix
You can customize the forked repository name by creating a `terraform.tfvars` file:
```hcl
repo_name_prefix = "my-custom-prefix"  # Creates: my-custom-prefix-detection-rules
```

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

## Next Steps

After deployment:
1. Access Kibana for both environments using the outputted URLs
2. Configure the Elastic GitHub integration in the production instance
3. Set up detection rules CI/CD pipeline in your forked repository
4. Test the DAC workflow by modifying detection rules

## Terraform Backend Configuration

For production use, consider configuring a remote backend to handle state encryption automatically. Example configurations:

### S3 Backend
```hcl
# backend.tf
terraform {
  backend "s3" {
    bucket  = "your-terraform-state-bucket"
    key     = "elastic-dac-demo/terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
  }
}
```

### Terraform Cloud
```hcl
# backend.tf
terraform {
  cloud {
    organization = "your-org"
    workspaces {
      name = "elastic-dac-demo"
    }
  }
}
```

After adding a backend configuration, run `terraform init -migrate-state` to move your existing state.

## Clean Up

To destroy all resources:
```bash
cd terraform
terraform destroy
```

Note: This will delete the Elastic Cloud deployments but not the GitHub fork.