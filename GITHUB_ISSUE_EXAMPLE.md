# GitHub Issue Examples for C2 Detection Demo

## Issue #42: [CRITICAL] Detection Gap - New C2 Infrastructure

**Labels:** `priority:critical` `threat-intel` `detection-gap` `c2`

**Assignees:** @detection-team

### Summary
Threat intelligence has identified active C2 infrastructure being used in ongoing attacks against our sector. Multiple organizations have reported compromise. We need immediate detection coverage.

### Threat Intelligence Context

**Source:** Industry ISAC alert + internal threat hunt findings

**Infrastructure Details:**
- Primary C2 Range: `185.220.101.0/24` 
  - Hosting Provider: KaiserNet (known bulletproof hosting)
  - First seen: 2025-01-15
  - Confidence: HIGH - confirmed via malware analysis

- Secondary Range: `194.147.78.0/24`
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
- **2025-01-18 14:30 UTC** - Threat intel received
- **2025-01-18 15:00 UTC** - Initial IoCs validated
- **2025-01-18 16:00 UTC** - Detection gap confirmed
- **2025-01-19 09:00 UTC** - Rule development started
- **TARGET: 2025-01-19 12:00 UTC** - Production deployment

---

## Alternative Issue Examples (Shorter Versions)

### Option 1: Ransomware C2
```markdown
Issue #89: Detect LockBit 3.0 C2 Infrastructure

New LockBit affiliate infrastructure identified:
- IP: 162.55.188.0/24 (Hetzner ranges)  
- Seen in 4 incidents this week
- HTTP beacons on port 8080
Need detection rule ASAP
```

### Option 2: Info Stealer C2
```markdown
Issue #67: RedLine Stealer C2 Detection

Threat feed update - RedLine C2 servers:
- 45.142.212.0/24 (SELECTEL)
- 91.242.229.0/24 (IPVOLUME)
Small POST requests every 5 minutes
Pattern: /api/v2/check or /api/v2/gate
```

### Option 3: APT C2
```markdown
Issue #101: APT29 Infrastructure Detection

CISA Alert AA25-011A - APT29 using new infrastructure:
- 185.174.100.0/24 (NL hosting)
- HTTPS beacons with jittered timing (45-90 sec)
- Masquerading as Microsoft update traffic
Critical priority - government sector targeting
```