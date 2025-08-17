#!/bin/bash
set -e

echo "Checking GitHub SSO authorization for Elastic organization..."

# Check if we can access the Elastic org
if gh api orgs/elastic --silent 2>/dev/null; then
    echo "✓ GitHub token is authorized for Elastic organization"
    exit 0
else
    echo "✗ GitHub token needs SSO authorization"
    echo ""
    echo "To authorize your token:"
    echo "1. Go to: https://github.com/settings/tokens"
    echo "2. Find your token and click 'Configure SSO'"
    echo "3. Authorize for 'elastic' organization"
    echo ""
    echo "Alternatively, run this command and follow the link:"
    echo "gh repo fork elastic/detection-rules --fork-name=test --clone=false"
    exit 1
fi