#!/bin/bash
# Simple Demo Commands - Just copy and paste these

# 1) Fork detection-rules repo (do in GitHub UI)
# Go to: https://github.com/elastic/detection-rules
# Click "Fork" button

# 2) Clone your fork
git clone https://github.com/YOUR_USERNAME/dac-demo-detection-rules.git
cd dac-demo-detection-rules

# 3) Python setup
python3 -m venv env
source env/bin/activate
pip install -e ".[dev]"
pip install lib/kql lib/kibana

# 4) Create authentication file
cat > .detection-rules-cfg.json << EOF
{
  "cloud_id": "YOUR_CLOUD_ID",
  "api_key": "YOUR_API_KEY"
}
EOF

# 5) Create feature branch
git checkout -b feature/new-detection-rule

# 6) Add a rule (example)
mkdir -p custom-rules/rules
cat > custom-rules/rules/my_rule.toml << EOF
[metadata]
rule_id = "custom-001"
[rule]
name = "My Detection Rule"
risk_score = 50
severity = "medium"
type = "query"
query = 'process.name : "suspicious.exe"'
EOF

# Commit
git add custom-rules/
git commit -m "feat: Add new detection rule"

# 6) Push feature branch
git push origin feature/new-detection-rule

# 7) Accept pull request (in GitHub UI)
# Auto-PR will be created
# Click "Merge pull request" on GitHub

# 8) Merge to main (after dev testing)
git checkout dev
git pull origin dev

# Create PR from dev to main
gh pr create --base main --head dev --title "Deploy to production"

# After approval, it auto-deploys to production

# 9) Rollback if needed
git checkout main
git revert HEAD
git push origin main