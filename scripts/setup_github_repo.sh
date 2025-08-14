#!/bin/bash
set -e

REPO_PREFIX="${REPO_PREFIX:-dac-demo}"
ORIGINAL_REPO_NAME="detection-rules"
REPO_NAME="${REPO_PREFIX}-${ORIGINAL_REPO_NAME}"
UPSTREAM_REPO="elastic/detection-rules"
TARGET_DIR="../../${REPO_NAME}"

if [ -z "$GITHUB_TOKEN" ]; then
    echo "Error: GITHUB_TOKEN environment variable is not set"
    exit 1
fi

echo "Setting up GitHub repository with name: ${REPO_NAME}..."

if [ -d "$TARGET_DIR" ]; then
    echo "Repository already exists at $TARGET_DIR"
    cd "$TARGET_DIR"
    git remote -v
    exit 0
fi

GITHUB_USER=$(gh api user --jq .login)
echo "GitHub user: $GITHUB_USER"

echo "Checking if fork ${REPO_NAME} already exists..."
if gh repo view "${GITHUB_USER}/${REPO_NAME}" &>/dev/null; then
    echo "Fork already exists, cloning it..."
else
    echo "Creating fork ${UPSTREAM_REPO} as ${REPO_NAME}..."
    gh repo fork "${UPSTREAM_REPO}" --fork-name="${REPO_NAME}" --clone=false || {
        echo "Error creating fork"
        exit 1
    }
fi

echo "Cloning fork to ${TARGET_DIR}..."
git clone "https://github.com/${GITHUB_USER}/${REPO_NAME}.git" "$TARGET_DIR"

cd "$TARGET_DIR"

echo "Adding upstream remote..."
git remote add upstream "https://github.com/${UPSTREAM_REPO}.git"

echo "Setting up branches..."
git fetch upstream
git checkout main || git checkout master
git pull upstream main || git pull upstream master

echo "Repository setup complete!"
echo "Location: $(pwd)"
echo "Repository name: ${REPO_NAME}"
git remote -v