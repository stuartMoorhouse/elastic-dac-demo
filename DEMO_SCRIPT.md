# Elastic Detection as Code - 5-Minute Demo Script

## Demo Scenario: C2 Beacon Detection

**Total Duration: 5 minutes**
**Scenario**: Threat intelligence identified new C2 infrastructure that needs detection coverage

---

## Pre-Demo Setup (Before Presentation)

### Critical: Python Environment Setup (DO THIS FIRST - Takes 2+ minutes)
```bash
 cd ../dac-demo-detection-rules
# IN THE dac-demo-detection-rules DIRECTORY:
  python3 -m venv env
  source env/bin/activate

  # Extract required Python version from pyproject.toml and check
  REQ_PYTHON=$(python -c "import toml; print(toml.load('pyproject.toml')['project']['requires-python'].replace('>=',''))")
  python -c "import sys; req=tuple(map(int,'$REQ_PYTHON'.split('.'))); exit(0 if sys.version_info[:2] >= req else 1)" && echo "Python version OK ($REQ_PYTHON+ required, got $(python --version))" || (echo "Error: Python $REQ_PYTHON+ required, got $(python --version)" && exit 1)

  pip install -e ".[dev]"
  pip install lib/kql lib/kibana

# This installation takes 2+ minutes - MUST be done before demo starts!
```

### Demo Environment Checklist
```bash
# Ensure all three Elastic instances are running
# Have Kibana tabs open for Local, Dev and Production environments
# Have GitHub repository page open
# Terminal ready in dac-demo-detection-rules directory WITH environment activated
# Verify Python environment is working: python -m detection_rules --help
# Have two browser profiles/windows ready:
#   - Main developer account (github_owner)
#   - Detection team lead account (detection-team-lead)
```

---

## Demo Steps
In dac-demo-detection-rules: 

# Switch to dev and pull latest before branching
# (feature branch MUST be based on dev, not main — otherwise the
# PR will include workflow-file drift between main and dev)
git checkout dev
git pull origin dev


### 1. Planning & Prioritization (30 seconds)

**Show:** GitHub Issues page
```markdown
Issue #42: [CRITICAL] Detection Gap - New C2 Infrastructure
Priority: Critical
Source: Threat Intelligence Team
Requirement: Detect beaconing to identified C2 IP ranges

Threat intel has identified active C2 infrastructure:
- IP Range: 185.220.101.0/24 (Bulletproof hosting provider)
- Associated with recent supply chain attacks
- Beacon pattern: Small packets (<1KB) with regular intervals
- Multiple customer environments affected

Need detection rule deployed ASAP.
```

Our threat intelligence team identified new C2 infrastructure being used in active campaigns. We need detection coverage immediately using our Detection as Code workflow.

---

### 2. Threat Research (30 seconds)

**Show:** Brief MITRE ATT&CK page (T1071 - Application Layer Protocol)

Attackers use C2 beacons for persistent access. We'll detect outbound connections to known malicious infrastructure with beaconing characteristics.

**Action:** Show prepared research notes:
```
Technique: T1071.001 - Web Protocols
Tactic: Command and Control
IOCs: 185.220.101.0/24 (Threat Intel feed)
Pattern: Regular intervals, small packet sizes
Context: Supply chain compromise campaign
```

---

### 3. Detection Creation (90 seconds)

**Show:** Local Kibana instance (Security → Rules)

**In Kibana UI:**
1. Click "Create new rule" → "Custom query"

2. **Define the query:**
event.category:network and 
network.direction:outbound and 
destination.ip:(
  185.220.101.0/24 or 
  194.147.78.0/24
) and 
network.bytes < 1024 and
not user.name:(security_scanner or backup_service)

3. **Fill in the rule details:**
   - Name: "Outbound C2 Beacon Activity to Known Malicious Infrastructure"
   - Description: "Detects beaconing behavior from known malicious IPs"
   - Severity: Critical
   - Risk score: 90

```

4. **Add MITRE ATT&CK mapping:**
   - Tactic: Command and Control  
   - Technique: T1071 - Application Layer Protocol
   - Sub-technique: T1071.001 - Web Protocol
5. **Save and enable the rule**

**Export to Git:**
In dac-demo-detection-rules:

```bash
# Create feature branch off dev
git checkout -b feature/c2-beacon-detection

# Export the rule from Kibana
python -m detection_rules kibana --space default export-rules \
  --directory dac-demo/rules/ --custom-rules-only --strip-version

# Commit and push
git add .
git commit -m "feat: Add C2 beacon detection for threat intel IOCs"
git push origin feature/c2-beacon-detection
```


---

### 4. Peer Review (60 seconds)

**Show:** Create PR

**Creating the PR (base = `dev` on your fork, NOT upstream elastic/detection-rules):**

Use this direct URL:
```
https://github.com/stuartMoorhouse/dac-demo-detection-rules/compare/dev...feature/c2-beacon-detection?expand=1
```

> **Note:** GitHub's "Compare & pull request" banner on a fork always targets the upstream `elastic/detection-rules` repo. If you land on that page, change the **"base repository"** dropdown from `elastic/detection-rules` to `stuartMoorhouse/dac-demo-detection-rules` and set base branch to `dev`.

**Key points to highlight:**
- Automatic PR creation after validation passes
- Required status checks running
- **Switch to Detection Team Lead browser/profile**
- Team Lead reviews: "LGTM - critical coverage for active threat"
- Team Lead approves the PR

---

### 5. Testing in Development (60 seconds)

**Show:** Merge PR to dev branch → Automatic deployment to Development Elastic

**Quick Kibana Demo (Development):**
- Show rule deployed in Security → Rules
- Point out it's already catching test events
- Rule is working as expected

After merging, the rule automatically deploys to Development. We can validate it's detecting beaconing patterns to the flagged C2 infrastructure.



<!-- 
---

### 6. Production Deployment (60 seconds)

**Show:** Create PR from dev to main branch

**Creating the PR (base = `main` on your fork, NOT upstream elastic/detection-rules):**

Use this direct URL:
```
https://github.com/stuartMoorhouse/dac-demo-detection-rules/compare/main...dev?expand=1
```

> **Note:** GitHub's "Compare & pull request" banner on a fork always targets the upstream `elastic/detection-rules` repo. If you land on that page, change the **"base repository"** dropdown from `elastic/detection-rules` to `stuartMoorhouse/dac-demo-detection-rules` and set base branch to `main`.

**Highlight:**
- Additional validation checks for production
- Version lock update (automatic)
- **Switch to Detection Team Lead browser/profile**
- Team Lead provides production approval
- Merge triggers production deployment

**Show Production Kibana:**
- Rule now active in production
- Version tracking in place
- Audit trail in Git history

With successful testing, we promote to production. The system automatically updates version tracking, maintains full audit trail, and deploys to our production Security instance.

---

## Demo Summary (30 seconds)

**Show:** Split screen with Git history and Production Kibana

**Key takeaways:**
- **Rapid threat response** - from threat intel to production in minutes
- **Test before commit** - rule validated in local Elastic first  
- **Automated pipeline** - no manual deployments or delays
- **Full audit trail** - compliance ready with complete history

We've shown how Detection as Code enables rapid response to emerging threats - critical C2 detection deployed through a controlled, auditable pipeline.

---

## Backup Talking Points (If Time Permits)

- **Rollback Demo**: Show GitHub Actions rollback workflow
- **Multiple Teams**: How different teams can work on rules simultaneously
- **Compliance**: Full change history for audit requirements
- **Scale**: Same workflow works for 10 or 10,000 rules

---

## Common Questions & Quick Answers

**Q: What if we need an emergency rule?**
A: Fast-track PR process, same workflow but expedited review

**Q: Can we still use Kibana?**
A: Read-only in production; all changes through Git

**Q: How do we handle sensitive rules?**
A: Private repository with restricted access

**Q: What about rule tuning?**
A: Same workflow - create PR with threshold adjustments -->