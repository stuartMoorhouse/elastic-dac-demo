# Elastic Detection as Code - 5-Minute Demo Script

## Demo Scenario: C2 Beacon Detection

**Total Duration: 5 minutes**
**Scenario**: Threat intelligence identified new C2 infrastructure that needs detection coverage

---

## Pre-Demo Setup (Before Presentation)
```bash
# Ensure all three Elastic instances are running
# Have Kibana tabs open for Local, Dev and Production environments
# Have GitHub repository page open
# Terminal ready in dac-demo-detection-rules directory
# Ensure detection-rules Python environment is activated
# Have two browser profiles/windows ready:
#   - Main developer account (github_owner)
#   - Detection team lead account (detection-team-lead)
```

---

## Demo Steps

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
2. **Fill in the rule details:**
   - Name: "Outbound C2 Beacon Activity to Known Malicious Infrastructure"
   - Description: "Detects beaconing behavior to threat intel flagged C2 ranges"
   - Severity: Critical
   - Risk score: 90

3. **Define the query:**
```kql
event.category:network and 
network.direction:outbound and 
destination.ip:(
  185.220.101.0/24 OR
  194.147.78.0/24
) and 
network.bytes < 1024 and
NOT user.name:(security_scanner OR backup_service)
```

4. **Add MITRE ATT&CK mapping:**
   - Tactic: Command and Control  
   - Technique: T1071.001 - Application Layer Protocol: Web Protocols

5. **Save and enable the rule**

I'm creating this rule in our local Elastic instance to validate the query. It detects small outbound packets to known C2 infrastructure from our threat intel feeds.

**Export to Git:**
```bash
# Create feature branch
git checkout -b feature/c2-beacon-detection

# Export the rule from Kibana
cd dac-demo-detection-rules
python -m detection_rules kibana export-rules \
  --rule-id c2-beacon-detection \
  --directory dac-demo/rules/

# Commit and push
git add .
git commit -m "feat: Add C2 beacon detection for threat intel IOCs"
git push origin feature/c2-beacon-detection
```

Now I export the tested rule to Git. This starts our automated CI/CD pipeline.

---

### 4. Peer Review (60 seconds)

**Show:** GitHub PR automatically created to dev branch

**Key points to highlight:**
- Automatic PR creation after validation passes
- Required status checks running
- **Switch to Detection Team Lead browser/profile**
- Team Lead reviews: "LGTM - critical coverage for active threat"
- Team Lead approves the PR

The push automatically created a pull request to our dev branch. After validation passes, our Detection Team Lead reviews and approves - the simple query is clear and effective for addressing the active threat.

---

### 5. Testing in Development (60 seconds)

**Show:** Merge PR to dev branch → Automatic deployment to Development Elastic

**Quick Kibana Demo (Development):**
- Show rule deployed in Security → Rules
- Point out it's already catching test events
- Rule is working as expected

After merging, the rule automatically deploys to Development. We can validate it's detecting beaconing patterns to the flagged C2 infrastructure.

---

### 6. Production Deployment (60 seconds)

**Show:** Create PR from dev to main branch

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
A: Same workflow - create PR with threshold adjustments