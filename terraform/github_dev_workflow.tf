# Create a custom workflow file for dev branch validation in the forked repository
# This allows us to run validation on dev branch without modifying upstream workflows

resource "github_repository_file" "dev_branch_validation_workflow" {
  repository = data.github_repository.detection_rules.name
  branch     = "dev"
  file       = ".github/workflows/${var.repo_name_prefix}-dev-branch-validate.yml"

  depends_on = [
    github_branch.dev, # Dev branch must exist first
    data.github_repository.detection_rules
  ]

  content = <<-EOT
name: ${var.repo_name_prefix} Dev Branch Validation

on:
  push:
    branches: [ "dev" ]

jobs:
  build:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v4
      with:
        fetch-depth: 1

    - name: Fetch main branch
      run: |
        git fetch origin main:refs/remotes/origin/main

    - name: Set up Python 3.13
      uses: actions/setup-python@v5
      with:
        python-version: '3.13'

    - name: Install dependencies
      run: |
        python -m pip install --upgrade pip
        pip cache purge
        pip install .[dev]
        pip install lib/kibana
        pip install lib/kql

    - name: Unit tests
      env:
        GITHUB_EVENT_NAME: "$${{ github.event_name}}"
      run: |
        python -m detection_rules test

    - name: Build release package
      run: |
        python -m detection_rules dev build-release
EOT

  commit_message = "Add custom dev branch validation workflow for ${var.repo_name_prefix}"
  commit_author  = "Terraform"
  commit_email   = "terraform@${var.repo_name_prefix}.local"

  lifecycle {
    ignore_changes = [commit_message, commit_author, commit_email]
  }
}

# Output to confirm workflow creation
output "dev_workflow_path" {
  value       = github_repository_file.dev_branch_validation_workflow.file
  description = "Path to the custom dev branch validation workflow"
}