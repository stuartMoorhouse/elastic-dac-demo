# Remove the upstream `.github/PULL_REQUEST_TEMPLATE.md` (uppercase) inherited
# from elastic/detection-rules. Terraform's github_repository_file.pr_template
# writes a lowercase `.github/pull_request_template.md`. GitHub's filesystem is
# case-sensitive so both can coexist, but macOS's default case-insensitive APFS
# collapses them into one on disk — causing `git add .` to pick up phantom
# "modifications" to whichever path loses the filesystem race.
#
# Runs BEFORE branch protection (same pattern as cleanup_inherited_workflows)
# so the DELETE isn't rejected by protection rules.

resource "null_resource" "cleanup_inherited_pr_template" {
  depends_on = [
    null_resource.create_fork,
    null_resource.clone_repository,
    github_branch.dev
  ]

  provisioner "local-exec" {
    command = <<-EOT
      set -e

      OWNER="${var.github_owner}"
      REPO="${local.repo_name}"
      export GH_TOKEN="${var.github_token}"

      delete_on_branch() {
        local branch="$1"
        local path=".github/PULL_REQUEST_TEMPLATE.md"

        if ! gh api "repos/$${OWNER}/$${REPO}/branches/$${branch}" >/dev/null 2>&1; then
          echo "  Branch $${branch} does not exist on remote, skipping"
          return 0
        fi

        local sha
        sha=$(gh api "repos/$${OWNER}/$${REPO}/contents/$${path}?ref=$${branch}" --jq .sha 2>/dev/null || echo "")
        if [ -z "$${sha}" ] || [ "$${sha}" = "null" ]; then
          echo "  $${branch}: no upstream $${path}, nothing to do"
          return 0
        fi

        gh api -X DELETE "repos/$${OWNER}/$${REPO}/contents/$${path}" \
          -f message="chore: remove case-collision duplicate of pull_request_template.md" \
          -f sha="$${sha}" \
          -f branch="$${branch}" >/dev/null 2>&1 \
          && echo "  $${branch}: deleted $${path}" \
          || echo "  $${branch}: WARN DELETE failed (likely branch protection already active)"
      }

      delete_on_branch main
      delete_on_branch dev

      echo "PR template case-collision cleanup complete."
    EOT
  }

  # Bootstrap-only: runs when the fork is (re)created. After that the file
  # is gone and won't come back unless the fork is recreated.
  triggers = {
    fork_id = null_resource.create_fork.id
  }
}
