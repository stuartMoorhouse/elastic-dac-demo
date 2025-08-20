# Configure pull request template for the repository
resource "github_repository_file" "pr_template" {
  repository = data.github_repository.detection_rules.name
  branch     = data.github_repository.detection_rules.default_branch
  file       = ".github/pull_request_template.md"
  
  content = <<-EOT
## Summary

<!-- Brief description of what this PR does -->

## Changes

<!-- List the specific changes/rules being added or modified -->

## Testing

<!-- How was this tested? -->
- [ ] Validated in Development environment
- [ ] Checked for false positives
- [ ] Verified detection logic

## Related Issues

<!-- Link any related issues -->
Resolves #

## Checklist

- [ ] Rule follows naming conventions
- [ ] MITRE ATT&CK mappings included
- [ ] Severity and risk scores are appropriate
- [ ] Documentation is clear
EOT

  commit_message = "chore: Add simplified PR template for Detection as Code workflow"
  
  depends_on = [
    null_resource.setup_dac_demo_rules,
    github_branch.dev  # Create after dev branch exists
  ]
  
  # This file should be created BEFORE branch protection
  # so we need to ensure branch protection depends on this
}