# Remove inherited GitHub Actions workflows from the Elastic detection-rules repository.
# These cause confusing failures in the fork (missing secrets like
# WRITE_TRADEBOT_GIST_TOKEN, dr_cloud_id) and spam the owner with failure emails.
#
# We delete directly via the GitHub Contents API on both main and dev so the
# remote state is authoritative and we don't fight branch-protection on git push.

resource "null_resource" "cleanup_inherited_workflows" {
  # Run BEFORE branch protection is applied so DELETE isn't blocked.
  # Must run AFTER fork creation and AFTER the dev branch exists (we clean both).
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

      KEEP_WORKFLOWS="deploy-to-prod.yml deploy-dev-to-development.yml feature-branch-validate.yml pr-validate.yml rollback-rules.yml auto-rollback.yml"

      cleanup_branch() {
        local branch="$1"
        echo "Cleaning inherited workflows on branch: $${branch}"

        # Does the branch exist on the remote?
        if ! gh api "repos/$${OWNER}/$${REPO}/branches/$${branch}" >/dev/null 2>&1; then
          echo "  Branch $${branch} does not exist on remote, skipping"
          return 0
        fi

        # Does the workflows dir exist on this branch?
        local listing
        listing=$(gh api "repos/$${OWNER}/$${REPO}/contents/.github/workflows?ref=$${branch}" 2>/dev/null || echo "")
        if [ -z "$${listing}" ] || [ "$${listing}" = "null" ]; then
          echo "  No .github/workflows on $${branch}, skipping"
          return 0
        fi

        local removed=0
        echo "$${listing}" | jq -r '.[] | select(.type=="file") | [.name, .path, .sha] | @tsv' | while IFS=$'\t' read -r name path sha; do
          case " $${KEEP_WORKFLOWS} " in
            *" $${name} "*)
              continue
              ;;
          esac
          echo "  Deleting inherited workflow on $${branch}: $${name}"
          gh api -X DELETE "repos/$${OWNER}/$${REPO}/contents/$${path}" \
            -f message="chore: remove inherited $${name} (not used by DAC demo)" \
            -f sha="$${sha}" \
            -f branch="$${branch}" >/dev/null 2>&1 || {
              echo "    WARN: DELETE failed for $${name} on $${branch} (likely branch protection). Skipping."
            }
          removed=$((removed + 1))
        done

        echo "  Done with $${branch}"
      }

      cleanup_branch main
      cleanup_branch dev

      echo "Workflow cleanup complete!"
    EOT
  }

  # Bootstrap-only: re-run only when the fork itself is (re)created. Once the
  # inherited workflows are gone they stay gone, and we don't want to fight
  # branch protection on every subsequent apply.
  triggers = {
    fork_id = null_resource.create_fork.id
  }
}
