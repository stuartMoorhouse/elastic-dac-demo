# Create demo GitHub issue for C2 detection
resource "null_resource" "create_demo_issue" {
  depends_on = [
    null_resource.enable_github_features,
    null_resource.clone_repository
  ]

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      echo "Creating demo GitHub issue for C2 detection..."
      
      # Wait for issues to be enabled
      sleep 3
      
      # Check if issue already exists
      EXISTING_ISSUE=$(gh issue list \
        --repo ${var.github_owner}/${local.repo_name} \
        --search "[CRITICAL] Detection Gap - New C2 Infrastructure" \
        --json number \
        --jq '.[0].number' || echo "")
      
      if [ -n "$${EXISTING_ISSUE}" ]; then
        echo "Issue #$${EXISTING_ISSUE} already exists, skipping creation"
      else
        # First create labels if they don't exist (ignore errors if they already exist)
        echo "Ensuring labels exist..."
        gh label create "priority:critical" --color "d73a4a" --description "Critical priority issue" --repo ${var.github_owner}/${local.repo_name} 2>/dev/null || true
        gh label create "threat-intel" --color "0075ca" --description "Threat intelligence related" --repo ${var.github_owner}/${local.repo_name} 2>/dev/null || true
        gh label create "detection-gap" --color "e99695" --description "Missing detection coverage" --repo ${var.github_owner}/${local.repo_name} 2>/dev/null || true
        
        # Create the issue
        ISSUE_URL=$(gh issue create \
          --repo ${var.github_owner}/${local.repo_name} \
          --title "[CRITICAL] Detection Gap - New C2 Infrastructure" \
          --label "priority:critical" \
          --label "threat-intel" \
          --label "detection-gap" \
          --body "### Summary
Threat intelligence has identified active C2 infrastructure being used in ongoing attacks against our sector. Multiple organizations have reported compromise. We need immediate detection coverage.

### Threat Intelligence Context

**Source:** Industry ISAC alert + internal threat hunt findings

**Infrastructure Details:**
- Primary C2 Range: \`185.220.101.0/24\` 
  - Hosting Provider: KaiserNet (known bulletproof hosting)
  - First seen: 2025-01-15
  - Confidence: HIGH - confirmed via malware analysis

- Secondary Range: \`194.147.78.0/24\`
  - Hosting Provider: FlokiNET 
  - Associated with same threat actor
  - Confidence: MEDIUM - behavioral correlation

**Observed TTPs:**
- Initial access via supply chain compromise
- Beacon intervals: 30-60 seconds
- Packet sizes: Consistently under 1KB
- Protocol: HTTPS on ports 443, 8443
- User-Agent: Mimics Chrome/Edge browsers

### Customer Impact
- 3 customers in financial sector confirmed affected
- 2 additional customers showing suspicious traffic patterns
- Active campaign - expecting additional infrastructure

### Detection Requirements

Create detection rule with following logic:
1. Identify outbound connections to specified IP ranges
2. Flag connections with small packet sizes (<1KB)
3. Alert on regular interval patterns (beaconing)
4. Exclude known legitimate services

**Note:** Detection engineer should develop appropriate KQL query based on these requirements and the threat intelligence provided.

### Test Data Available
- PCAP from affected customer (see SecOps shared drive)
- Beacon simulator configured in lab environment
- Historical data in Development cluster showing patterns

### Success Criteria
- [ ] Rule detects known C2 traffic in test data
- [ ] Less than 0.1% false positive rate
- [ ] Deployed to all production environments
- [ ] Alert routing to Tier 2 SOC queue
- [ ] Documentation updated in runbook

### References
- ISAC Alert: TLP:AMBER-2025-0142
- Vendor Report: CrowdStrike HELIX-2025-881
- MITRE ATT&CK: T1071.001 (Application Layer Protocol)
- Related campaign: https://attack.mitre.org/groups/G0139/

### Timeline
- **$(date -u -v-2d '+%Y-%m-%d %H:%M UTC' 2>/dev/null || date -u -d '2 days ago' '+%Y-%m-%d %H:%M UTC' 2>/dev/null || echo '2025-01-18 12:00 UTC')** - Threat intel received
- **$(date -u -v-2d '+%Y-%m-%d %H:%M UTC' 2>/dev/null || date -u -d '2 days ago' '+%Y-%m-%d %H:%M UTC' 2>/dev/null || echo '2025-01-18 14:00 UTC')** - Initial IoCs validated
- **$(date -u -v-1d '+%Y-%m-%d %H:%M UTC' 2>/dev/null || date -u -d 'yesterday' '+%Y-%m-%d %H:%M UTC' 2>/dev/null || echo '2025-01-19 10:00 UTC')** - Detection gap confirmed
- **$(date -u '+%Y-%m-%d %H:%M UTC')** - Rule development started
- **TARGET: $(date -u -v+1d '+%Y-%m-%d %H:%M UTC' 2>/dev/null || date -u -d 'tomorrow' '+%Y-%m-%d %H:%M UTC' 2>/dev/null || echo '2025-01-21 18:00 UTC')** - Production deployment")
        
        echo "Created issue: $${ISSUE_URL}"
        
        # Store issue URL for output
        echo "$${ISSUE_URL}" > /tmp/demo_issue_url.txt
      fi
    EOT
  }

  triggers = {
    repo_name = local.repo_name
  }
}

# Output the demo issue URL
output "demo_issue_url" {
  value = "https://github.com/${var.github_owner}/${local.repo_name}/issues"
  description = "URL to the GitHub issues page with the demo C2 detection issue"
  
  depends_on = [null_resource.create_demo_issue]
}