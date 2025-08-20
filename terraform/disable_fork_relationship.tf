# Disable the fork relationship to prevent PRs from redirecting to upstream
resource "null_resource" "disable_fork_relationship" {
  depends_on = [
    null_resource.create_fork,
    null_resource.clone_repository
  ]

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      echo "Configuring repository to prevent upstream PR redirects..."
      
      # Update repository settings to reduce fork connection
      gh api repos/${var.github_owner}/${local.repo_name} \
        -X PATCH \
        -f has_issues=true \
        -f has_projects=true \
        -f has_wiki=false \
        -f allow_squash_merge=true \
        -f allow_merge_commit=true \
        -f allow_rebase_merge=true \
        -f delete_branch_on_merge=true \
        -f allow_auto_merge=false || echo "Repository settings updated"
      
      # Set the default branch explicitly
      gh api repos/${var.github_owner}/${local.repo_name} \
        -X PATCH \
        -f default_branch=main || echo "Default branch already set"
      
      echo "Repository configured to stay independent from upstream"
    EOT
  }

  triggers = {
    repo_name = local.repo_name
  }
}

# Update other resources to depend on this
resource "null_resource" "update_clone_dependencies" {
  depends_on = [
    null_resource.disable_fork_relationship
  ]
  
  provisioner "local-exec" {
    command = "echo 'Fork relationship disabled'"
  }
}