---
name: audit_update_skills
description: Audit and update ZeroClaw skills by selectively enabling specific skills in the workspace while disabling global open skills for better security control.
---

# Audit and Update ZeroClaw Skills

This skill provides a systematic approach to auditing and updating ZeroClaw skills, with a focus on security-conscious selective enabling of skills.

## When to use

- Use case 1: When you need to review which skills are currently loaded and available to ZeroClaw
- Use case 2: When you want to reduce the attack surface by limiting available skills
- Use case 3: When you need to selectively enable only specific skills from the open-skills repository
- Use case 4: When auditing security configurations related to skill execution
- Use case 5: When adding or removing skills from the workspace

## Required tools / APIs

- SSH access via Tailscale: `tailscale ssh ubuntu@zeroclaw.ruffe-court.ts.net`
- Systemd service management: `sudo systemctl restart zeroclaw.service`
- Text editing tools: `sed`, `grep`, `cat`, `nano`
- File operations: `cp`, `ls`, `mkdir`

## Server Information

- **Server:** ubuntu@zeroclaw.ruffe-court.ts.net
- **User:** ubuntu (with sudo privileges)
- **Config file:** `~/.zeroclaw/config.toml`
- **Global skills directory:** `~/open-skills/skills/`
- **Workspace skills directory:** `~/.zeroclaw/workspace/skills/`

---

## Audit Procedure

### Step 1: Check Current Skills Status

```bash
# SSH into the server
tailscale ssh ubuntu@zeroclaw.ruffe-court.ts.net

# Check currently loaded skills
sudo journalctl -u zeroclaw.service --no-pager -n 200 | grep -i "Skills:"

# Check skills configuration
grep -A 5 "^\[skills\]" ~/.zeroclaw/config.toml

# List all available global skills
ls ~/open-skills/skills/ | wc -l
ls ~/open-skills/skills/

# List workspace skills
ls ~/.zeroclaw/workspace/skills/
```

### Step 2: Review Security Configuration

```bash
# Check autonomy settings
grep -A 30 "^\[autonomy\]" ~/.zeroclaw/config.toml

# Check security sandbox settings
grep -A 5 "^\[security.sandbox\]" ~/.zeroclaw/config.toml

# Check security resource limits
grep -A 5 "^\[security.resources\]" ~/.zeroclaw/config.toml

# Check forbidden paths
grep -A 20 "forbidden_paths" ~/.zeroclaw/config.toml

# Check allowed commands
grep -A 20 "allowed_commands" ~/.zeroclaw/config.toml
```

### Step 3: Identify High-Risk Skills

Review skills in `~/open-skills/skills/` and categorize them:

**High Risk Skills:**
- browser-automation-agent - Browser automation capabilities
- using-web-scraping - Web scraping functionality
- anonymous-file-upload - External file upload
- database-query-and-export - Database access

**Medium Risk Skills:**
- get-crypto-price - External API calls
- check-crypto-address-balance - Blockchain queries
- using-telegram-bot - External messaging
- using-nostr - External protocol

**Low Risk Skills:**
- generate-qr-code-natively - Local QR generation
- csv-data-summarizer - Local data processing
- changelog-generator - Local file operations
- ip-lookup - External API (limited scope)

---

## Update Procedure: Selective Skills Enabling (Recommended)

### Step 1: Backup Current Configuration

```bash
# Create backup with timestamp
cp ~/.zeroclaw/config.toml ~/.zeroclaw/config.toml.backup.skills.$(date +%Y%m%d_%H%M%S)

# Verify backup
ls -lh ~/.zeroclaw/config.toml.backup.skills.* | tail -1
```

### Step 2: Disable Global Open Skills

```bash
# Modify configuration to disable global skills
sed -i 's/^open_skills_enabled = true/open_skills_enabled = false/' ~/.zeroclaw/config.toml

# Verify the change
grep -A 1 '^\[skills\]' ~/.zeroclaw/config.toml
```

Expected output:
```
[skills]
open_skills_enabled = false
```

### Step 3: Prepare Workspace Skills Directory

```bash
# Create workspace skills directory if it doesn't exist
mkdir -p ~/.zeroclaw/workspace/skills

# Check existing workspace skills
ls ~/.zeroclaw/workspace/skills/
```

### Step 4: Copy Desired Skills to Workspace

```bash
# List available skills to choose from
ls ~/open-skills/skills/

# Copy specific skills (example: low-risk skills)
cp -r ~/open-skills/skills/ip-lookup ~/.zeroclaw/workspace/skills/
cp -r ~/open-skills/skills/csv-data-summarizer ~/.zeroclaw/workspace/skills/
cp -r ~/open-skills/skills/generate-qr-code-natively ~/.zeroclaw/workspace/skills/
cp -r ~/open-skills/skills/changelog-generator ~/.zeroclaw/workspace/skills/

# For user-requested specific skills
cp -r ~/open-skills/skills/browser-automation-agent ~/.zeroclaw/workspace/skills/
cp -r ~/open-skills/skills/get-crypto-price ~/.zeroclaw/workspace/skills/

# Verify copied skills
ls -la ~/.zeroclaw/workspace/skills/
```

### Step 5: Restart ZeroClaw Service

```bash
# Restart the service
sudo systemctl restart zeroclaw.service

# Wait for service to start
sleep 3

# Check service status
sudo systemctl status zeroclaw.service --no-pager -l | head -15

# Verify loaded skills in logs
sudo journalctl -u zeroclaw.service --no-pager -n 50 | grep "Skills:"
```

Expected output shows only workspace skills:
```
🧩 Skills: telegram_bot, feishu_bot, ip-lookup, csv-data-summarizer
```

---

## Verification and Validation

### Verify Configuration

```bash
# Confirm open_skills_enabled is false
grep "open_skills_enabled" ~/.zeroclaw/config.toml

# List workspace skills
ls ~/.zeroclaw/workspace/skills/

# Check loaded skills count
sudo journalctl -u zeroclaw.service --no-pager -n 100 | grep "Skills:" | tail -1
```

### Compare Before/After

| Metric | Before | After |
|--------|--------|-------|
| open_skills_enabled | true | false |
| Loaded Skills Count | 26+ | 4-10 (workspace only) |
| Global Skills | All enabled | All disabled |
| Workspace Skills | Few | Selected skills |

---

## Adding New Skills

To add more skills after initial setup:

```bash
# 1. Copy the skill to workspace
cp -r ~/open-skills/skills/<skill-name> ~/.zeroclaw/workspace/skills/

# 2. Verify the skill files
ls -la ~/.zeroclaw/workspace/skills/<skill-name>/

# 3. Restart service
sudo systemctl restart zeroclaw.service

# 4. Verify skill is loaded
sudo journalctl -u zeroclaw.service --no-pager -n 50 | grep "Skills:"
```

---

## Removing Skills

To remove a skill from the workspace:

```bash
# 1. Remove the skill directory
rm -rf ~/.zeroclaw/workspace/skills/<skill-name>

# 2. Restart service
sudo systemctl restart zeroclaw.service

# 3. Verify skill is removed
sudo journalctl -u zeroclaw.service --no-pager -n 50 | grep "Skills:"
```

---

## Security Best Practices

### Recommended Configuration

```toml
[skills]
open_skills_enabled = false  # Disable global skills

[autonomy]
level = "supervised"         # Supervised mode
workspace_only = true        # Restrict to workspace
require_approval_for_medium_risk = true
block_high_risk_commands = true

[security.sandbox]
backend = "auto"             # Use sandboxing

[security.resources]
max_memory_mb = 512
max_cpu_time_seconds = 60
max_subprocesses = 10
```

### Security Checklist

- [ ] Global open skills disabled (`open_skills_enabled = false`)
- [ ] Only necessary skills in workspace
- [ ] Autonomy level set to "supervised" or "restricted"
- [ ] `workspace_only = true` enabled
- [ ] Sensitive paths in `forbidden_paths`
- [ ] Only safe commands in `allowed_commands`
- [ ] Sandbox enabled
- [ ] Resource limits configured
- [ ] Audit logging enabled

### High-Risk Skills to Avoid

Do NOT copy these skills to workspace unless absolutely necessary:

- `browser-automation-agent` - Can automate browsers
- `using-web-scraping` - Can scrape websites
- `anonymous-file-upload` - Can upload files externally
- `database-query-and-export` - Can access databases

---

## Troubleshooting

### Service Won't Start

```bash
# Check service logs
sudo journalctl -u zeroclaw.service -n 50

# Check for configuration errors
cat ~/.zeroclaw/config.toml | grep -A 5 "\[skills\]"

# Verify TOML syntax
# Look for unclosed brackets, missing quotes, etc.
```

### Skills Not Loading

```bash
# Verify skill directory structure
ls -la ~/.zeroclaw/workspace/skills/<skill-name>/

# Check SKILL.md exists
cat ~/.zeroclaw/workspace/skills/<skill-name>/SKILL.md | head -10

# Check for security warnings in logs
sudo journalctl -u zeroclaw.service --no-pager | grep -i "insecure skill"
```

### Skill Security Warnings

If you see warnings like:
```
skipping insecure skill directory: SKILL.md: markdown link escapes skill root
```

This is a built-in security feature. The skill has been automatically blocked because:
- It contains markdown links pointing outside the skill directory
- This prevents path traversal attacks

**Solution:** Do not use this skill, or manually review and fix the SKILL.md file.

---

## Complete Audit Script

Here's a complete script to run a full audit:

```bash
#!/bin/bash
# ZeroClaw Skills Audit Script

echo "=== ZeroClaw Skills Audit Report ==="
echo "Date: $(date)"
echo ""

echo "1. Configuration Status:"
grep -A 2 "^\[skills\]" ~/.zeroclaw/config.toml
echo ""

echo "2. Currently Loaded Skills:"
sudo journalctl -u zeroclaw.service --no-pager -n 200 | grep "Skills:" | tail -1
echo ""

echo "3. Global Skills Available: $(ls ~/open-skills/skills/ | wc -l)"
echo ""

echo "4. Workspace Skills: $(ls ~/.zeroclaw/workspace/skills/ 2>/dev/null | wc -l)"
ls ~/.zeroclaw/workspace/skills/ 2>/dev/null
echo ""

echo "5. Security Configuration:"
echo "   Autonomy Level: $(grep 'level = ' ~/.zeroclaw/config.toml | head -1)"
echo "   Workspace Only: $(grep 'workspace_only = ' ~/.zeroclaw/config.toml)"
echo "   Sandbox Backend: $(grep 'backend = ' ~/.zeroclaw/config.toml | grep -A1 sandbox | tail -1)"
echo ""

echo "6. Service Status:"
sudo systemctl is-active zeroclaw.service
echo ""

echo "7. Recent Warnings/Errors:"
sudo journalctl -u zeroclaw.service --no-pager -n 50 | grep -E "WARN|ERROR" | tail -5
echo ""

echo "=== Audit Complete ==="
```

Save as `~/.zeroclaw/workspace/scripts/audit_skills.sh` and run with:
```bash
bash ~/.zeroclaw/workspace/scripts/audit_skills.sh
```

---

## Quick Reference Commands

### Check Status
```bash
# Quick status check
tailscale ssh ubuntu@zeroclaw.ruffe-court.ts.net \
  "grep 'open_skills_enabled' ~/.zeroclaw/config.toml && \
   sudo journalctl -u zeroclaw.service --no-pager -n 50 | grep 'Skills:'"
```

### Add Skill
```bash
# Quick add skill
tailscale ssh ubuntu@zeroclaw.ruffe-court.ts.net \
  "cp -r ~/open-skills/skills/<SKILL_NAME> ~/.zeroclaw/workspace/skills/ && \
   sudo systemctl restart zeroclaw.service"
```

### Remove Skill
```bash
# Quick remove skill
tailscale ssh ubuntu@zeroclaw.ruffe-court.ts.net \
  "rm -rf ~/.zeroclaw/workspace/skills/<SKILL_NAME> && \
   sudo systemctl restart zeroclaw.service"
```

### Restore Backup
```bash
# Restore from backup
tailscale ssh ubuntu@zeroclaw.ruffe-court.ts.net \
  "cp ~/.zeroclaw/config.toml.backup.skills.LATEST ~/.zeroclaw/config.toml && \
   sudo systemctl restart zeroclaw.service"
```

---

## Notes

- Always backup configuration before making changes
- Test skills after adding/removing to ensure they work correctly
- Monitor audit logs after changes: `tail -f ~/.zeroclaw/audit.log`
- Review security implications before adding high-risk skills
- Keep a record of which skills are enabled and why

---

## References

- ZeroClaw Configuration: `~/.zeroclaw/config.toml`
- Open Skills Repository: `~/open-skills/`
- Skills Documentation: https://openskills.besoeasy.com/
- Server: ubuntu@zeroclaw.ruffe-court.ts.net
- Service: zeroclaw.service