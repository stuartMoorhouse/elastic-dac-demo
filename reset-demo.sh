#!/usr/bin/env bash
# Reset the DAC demo to a pre-demo state without destroying infra.
# Idempotent and non-interactive. Safe to run repeatedly between rehearsals.
#
# Scope: demo runs up to the merge-to-dev step, so this script:
#   - Deletes custom (non-prebuilt) detection rules from local, dev, prod clusters
#   - Closes open PRs on the fork
#   - Deletes all branches except main and dev
#   - Resets dev back to main (wipes rule files merged during the demo)
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
# Step 4: reset dev to match main (wipe any rules merged during the demo)
# ---------------------------------------------------------------------------
echo "Step 4: Resetting dev to main"
if [[ -d "${CLONE_DIR}/.git" ]]; then
  cd "${CLONE_DIR}"
  git fetch --prune origin >/dev/null 2>&1
  main_sha="$(git rev-parse origin/main)"
  dev_sha="$(git rev-parse origin/dev 2>/dev/null || echo '')"

  if [[ "${main_sha}" == "${dev_sha}" ]]; then
    echo "  dev already matches main (${main_sha:0:7})"
  else
    git update-ref refs/heads/_reset_dev "${main_sha}"
    git push --force-with-lease origin "_reset_dev:refs/heads/dev" >/dev/null
    git update-ref -d refs/heads/_reset_dev
    echo "  dev reset to main (${main_sha:0:7})"
  fi

  echo "Step 5: Cleaning local clone"
  git checkout main >/dev/null 2>&1
  git reset --hard origin/main >/dev/null 2>&1
  git fetch --prune origin >/dev/null 2>&1
  for b in $(git branch --format='%(refname:short)' | grep -vE '^(main|dev)$'); do
    git branch -D "${b}" >/dev/null 2>&1 && echo "  deleted local branch ${b}" || true
  done
  git clean -fdx >/dev/null 2>&1
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
