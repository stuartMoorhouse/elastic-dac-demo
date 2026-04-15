#!/usr/bin/env bash
# Reset the DAC demo to a pre-demo state without destroying infra.
# Idempotent and non-interactive. Safe to run repeatedly between rehearsals.
#
# Scope: demo runs up to the merge-to-dev step, so this script:
#   - Deletes custom (non-prebuilt) detection rules from local, dev, prod clusters
#   - Closes open PRs on the fork
#   - Deletes all branches except main and dev
#   - Resets dev back to main's tree via a reset PR (respects branch protection —
#     no force-push required; PR-based so the reset is auditable in git history)
#   - Cleans the local clone working tree
#   - Reopens issue #1 if closed

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="${SCRIPT_DIR}/terraform"

cd "${TERRAFORM_DIR}"

tf_out() { terraform output -raw "$1" 2>/dev/null || true; }

REPO_NAME="$(tf_out github_repository_name)"
REPO_OWNER="$(terraform output -json 2>/dev/null | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("github_repository_url",{}).get("value","").split("/")[-2])' 2>/dev/null || true)"
CLONE_DIR="${SCRIPT_DIR}/../${REPO_NAME}"

if [[ -z "${REPO_NAME}" ]]; then
  echo "ERROR: could not read github_repository_name from terraform outputs." >&2
  echo "Has 'terraform apply' been run?" >&2
  exit 1
fi

# Team lead identity — needed to approve the reset PR into dev (dev branch
# protection requires 1 approving review, and GitHub does not allow a PR's
# author to approve their own PR).
TEAM_LEAD_TOKEN="${TF_VAR_detection_team_lead_token:-}"
if [[ -z "${TEAM_LEAD_TOKEN}" ]]; then
  echo "ERROR: TF_VAR_detection_team_lead_token is not set." >&2
  echo "       The reset PR into dev requires an approval from the detection" >&2
  echo "       team lead account. Source .envrc (direnv allow) before running." >&2
  exit 1
fi

echo "Repo:      ${REPO_OWNER}/${REPO_NAME}"
echo "Clone dir: ${CLONE_DIR}"
echo

# ---------------------------------------------------------------------------
# Step 1: delete custom detection rules from every cluster
# ---------------------------------------------------------------------------
delete_custom_rules() {
  local label="$1" kibana="$2" password="$3"

  if [[ -z "${kibana}" || -z "${password}" ]]; then
    echo "  ${label}: skipped (no credentials)"
    return 0
  fi

  local ids
  ids="$(curl -sS -u "elastic:${password}" \
    "${kibana}/api/detection_engine/rules/_find?per_page=10000&filter=alert.attributes.params.immutable:false" \
    -H 'Content-Type: application/json' \
    | python3 -c 'import json,sys; d=json.load(sys.stdin); print(" ".join(r["id"] for r in d.get("data",[])))' 2>/dev/null || true)"

  if [[ -z "${ids}" ]]; then
    echo "  ${label}: no custom rules"
    return 0
  fi

  local payload
  payload="$(python3 -c 'import json,sys; print(json.dumps({"action":"delete","ids":sys.argv[1].split()}))' "${ids}")"

  curl -sS -u "elastic:${password}" \
    -X POST "${kibana}/api/detection_engine/rules/_bulk_action" \
    -H 'kbn-xsrf: true' -H 'Content-Type: application/json' \
    -d "${payload}" >/dev/null

  local count
  count="$(echo "${ids}" | wc -w | tr -d ' ')"
  echo "  ${label}: deleted ${count} custom rule(s)"
}

echo "Step 1: Deleting custom rules from Kibana clusters"
delete_custom_rules "local      " "$(tf_out local_kibana_endpoint)"       "$(tf_out local_elasticsearch_password)"
delete_custom_rules "development" "$(tf_out development_kibana_endpoint)" "$(tf_out development_elasticsearch_password)"
delete_custom_rules "production " "$(tf_out production_kibana_endpoint)"  "$(tf_out production_elasticsearch_password)"
echo

# ---------------------------------------------------------------------------
# Step 2: close open PRs on the fork
# ---------------------------------------------------------------------------
echo "Step 2: Closing open pull requests"
open_prs="$(gh pr list --repo "${REPO_OWNER}/${REPO_NAME}" --state open --json number -q '.[].number' 2>/dev/null || true)"
if [[ -z "${open_prs}" ]]; then
  echo "  no open PRs"
else
  for pr in ${open_prs}; do
    gh pr close --repo "${REPO_OWNER}/${REPO_NAME}" "${pr}" >/dev/null
    echo "  closed PR #${pr}"
  done
fi
echo

# ---------------------------------------------------------------------------
# Step 3: delete every remote branch except main and dev
# ---------------------------------------------------------------------------
echo "Step 3: Deleting demo branches on origin"
branches="$(gh api "repos/${REPO_OWNER}/${REPO_NAME}/branches" --paginate -q '.[].name' 2>/dev/null || true)"
for b in ${branches}; do
  if [[ "${b}" == "main" || "${b}" == "dev" ]]; then
    continue
  fi
  gh api -X DELETE "repos/${REPO_OWNER}/${REPO_NAME}/git/refs/heads/${b}" >/dev/null 2>&1 \
    && echo "  deleted ${b}" \
    || echo "  could not delete ${b} (may be protected)"
done
echo

# ---------------------------------------------------------------------------
# Step 4: reset dev's tree to match main via a PR (respects branch protection)
#
# We can't force-push dev (allows_force_pushes=false), and we can't
# fast-forward a main→dev push because dev has commits main doesn't. So:
#   1. Create a short-lived branch off dev.
#   2. Rewrite its tree to match main's tree in one commit.
#   3. Open a PR dev ← reset branch (authored by ${REPO_OWNER}).
#   4. Approve the PR with the detection team lead's token (GitHub blocks
#      authors from self-approving).
#   5. Merge the PR and delete the reset branch.
# After the merge, dev's tree equals main's. History records the reset.
# ---------------------------------------------------------------------------
echo "Step 4: Resetting dev to main via PR"
if [[ -d "${CLONE_DIR}/.git" ]]; then
  cd "${CLONE_DIR}"
  git fetch --prune origin >/dev/null 2>&1
  main_sha="$(git rev-parse origin/main)"
  dev_sha="$(git rev-parse origin/dev 2>/dev/null || echo '')"

  if [[ -z "${dev_sha}" ]]; then
    echo "  dev branch missing on origin; skipping"
  elif [[ "$(git rev-parse "origin/main^{tree}")" == "$(git rev-parse "origin/dev^{tree}")" ]]; then
    echo "  dev tree already matches main (${main_sha:0:7}); skipping"
  else
    reset_branch="reset/dev-to-main-$(date -u +%Y%m%d-%H%M%S)"
    git checkout -B "${reset_branch}" "origin/dev" >/dev/null 2>&1
    # Replace the index+working tree with main's tree, keeping dev's history.
    git read-tree -m -u "origin/main"
    if git diff --cached --quiet; then
      echo "  nothing to reset (dev tree already matches main)"
      git checkout main >/dev/null 2>&1
      git branch -D "${reset_branch}" >/dev/null 2>&1 || true
    else
      git -c user.name="reset-demo" -c user.email="reset-demo@local" \
        commit -m "reset: restore dev to main tree for demo rehearsal" >/dev/null
      git push origin "${reset_branch}" >/dev/null 2>&1
      pr_url="$(gh pr create \
        --repo "${REPO_OWNER}/${REPO_NAME}" \
        --base dev --head "${reset_branch}" \
        --title "reset: restore dev to main tree for demo rehearsal" \
        --body "Automated reset PR from reset-demo.sh. Brings dev's tree back to main so the next rehearsal starts from a clean state." \
        2>/dev/null || true)"
      if [[ -z "${pr_url}" ]]; then
        echo "  ERROR: could not open reset PR" >&2
      else
        pr_num="${pr_url##*/}"

        # Approve as the detection team lead (PR author can't self-approve).
        if GH_TOKEN="${TEAM_LEAD_TOKEN}" gh pr review \
            --repo "${REPO_OWNER}/${REPO_NAME}" \
            --approve "${pr_num}" \
            --body "Automated approval from reset-demo.sh" >/dev/null 2>&1; then
          echo "  approved reset PR #${pr_num} as team lead"
        else
          echo "  WARN: team lead approval failed for PR #${pr_num}" >&2
        fi

        # Poll briefly for mergeability, then merge. Merge-commit preserves audit trail.
        merged=0
        for _ in 1 2 3 4 5; do
          if gh pr merge --repo "${REPO_OWNER}/${REPO_NAME}" --merge --delete-branch "${pr_num}" >/dev/null 2>&1; then
            echo "  merged reset PR #${pr_num}; dev tree now matches main (${main_sha:0:7})"
            merged=1
            break
          fi
          sleep 2
        done
        if [[ "${merged}" -eq 0 ]]; then
          echo "  WARN: reset PR #${pr_num} could not be merged — merge manually" >&2
        fi
      fi
      git checkout main >/dev/null 2>&1
      git branch -D "${reset_branch}" >/dev/null 2>&1 || true
    fi
  fi

  echo "Step 5: Cleaning local clone"
  git checkout main >/dev/null 2>&1
  git reset --hard origin/main >/dev/null 2>&1
  git fetch --prune origin >/dev/null 2>&1
  for b in $(git branch --format='%(refname:short)' | grep -vE '^(main|dev)$'); do
    git branch -D "${b}" >/dev/null 2>&1 && echo "  deleted local branch ${b}" || true
  done
  # Preserve infra-owned files (written by terraform, not by the demo):
  #   .env, .detection-rules-cfg*  — Local cluster credentials / API key
  #   env/                         — Python venv (2+ min to rebuild)
  git clean -fdx \
    -e .env \
    -e '.detection-rules-cfg*' \
    -e env \
    >/dev/null 2>&1
  cd "${SCRIPT_DIR}"
else
  echo "  local clone not found at ${CLONE_DIR}; skipping local reset"
  echo "Step 5: Cleaning local clone — skipped"
fi
echo

# ---------------------------------------------------------------------------
# Step 6: reopen issue #1 if it was closed during the demo
# ---------------------------------------------------------------------------
echo "Step 6: Resetting issue #1"
issue_state="$(gh issue view 1 --repo "${REPO_OWNER}/${REPO_NAME}" --json state -q .state 2>/dev/null || true)"
case "${issue_state}" in
  CLOSED) gh issue reopen 1 --repo "${REPO_OWNER}/${REPO_NAME}" >/dev/null && echo "  reopened issue #1" ;;
  OPEN)   echo "  issue #1 already open" ;;
  *)      echo "  issue #1 not found; skipping" ;;
esac
echo

echo "Reset complete."
