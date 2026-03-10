# HEARTBEAT.md — Periodic Operational Checks

*BabyClaw's automated monitoring and maintenance heartbeat*

## Daily Automated Checks (Every 6 Hours)

### System Health
- [ ] Container status: `lxc info chatekclaw` (verify running)
- [ ] Resource usage: CPU, memory, disk (check for anomalies)
- [ ] Service status: All systemd services running
- [ ] Docker containers: All expected containers up and healthy

### Service Health Endpoints
- [ ] Tuwunel: `curl -f http://localhost:8008/_matrix/client/versions || alert`
- [ ] MAS: `curl -f http://localhost:8080/.well-known/openid-configuration || alert`
- [ ] HedgeDoc: `curl -f http://localhost:3000 || alert`
- [ ] Cloudflare Tunnel: DNS resolution check for chatek.co and m.chatek.co

### Log Monitoring
- [ ] Check for ERROR level entries in last 6 hours
- [ ] Check for authentication failures spike
- [ ] Check for resource exhaustion warnings
- [ ] Review user-facing error reports

### Security Quick Scan
- [ ] Failed authentication attempts count
- [ ] Unusual traffic patterns
- [ ] Resource usage spikes

---

## Weekly Checks (Every Sunday 02:00 UTC)

### Backup Verification
- [ ] LXC snapshot created successfully
- [ ] PostgreSQL backups intact (MAS + HedgeDoc)
- [ ] SQLite backup for Tuwunel
- [ ] Test restore procedure (dry-run)

### Security Review
- [ ] Review MAS client configurations
- [ ] Check for security updates available
- [ ] Audit authentication logs for anomalies
- [ ] Verify Cloudflare Tunnel certificates

### Performance Analysis
- [ ] Review resource usage trends
- [ ] Identify optimization opportunities
- [ ] Check response time metrics
- [ ] Analyze user activity patterns

### Maintenance Tasks
- [ ] Clean up old log files (keep 30 days)
- [ ] Review and rotate daily memory logs
- [ ] Update documentation if needed
- [ ] Verify monitoring alerts are working

### Reporting
- [ ] Generate weekly status report for ClawPapa
- [ ] Document any incidents and resolutions
- [ ] Update operational runbooks with new learnings

---

## Monthly Checks (1st of each month 03:00 UTC)

### Full System Audit
- [ ] Security patch review and application
- [ ] Full backup restore test (in isolated environment)
- [ ] Capacity planning review
- [ ] Service version update check

### Performance Deep Dive
- [ ] Comprehensive performance profiling
- [ ] Database optimization (PostgreSQL vacuum, SQLite integrity)
- [ ] Resource allocation review and adjustment
- [ ] Response time trend analysis

### Documentation Review
- [ ] TOOLS.md accuracy and completeness
- [ ] Runbook effectiveness evaluation
- [ ] Incident response procedure testing
- [ ] User documentation updates

### Strategic Review
- [ ] User growth and engagement metrics
- [ ] Feature request analysis
- [ ] Infrastructure scaling assessment
- [ ] ClawPapa strategic alignment check

---

## Real-Time Alert Triggers

### Critical Alerts (Immediate Response)
- Service down > 1 minute
- Memory usage > 90%
- Disk usage > 85%
- CPU sustained > 80% for 5+ minutes
- Authentication failure spike > 10 failures/minute
- Cloudflare Tunnel disconnection

### Warning Alerts (Same Day Response)
- Service response time > 500ms
- Memory usage > 75%
- Disk usage > 70%
- Unusual traffic patterns
- Certificate expiration < 7 days
- Backup verification failure

### Info Alerts (Weekly Review)
- Non-critical service degradation
- Resource usage trends approaching thresholds
- User registration anomalies
- Performance optimization opportunities

---

## Automated Monitoring Commands

### Health Check Script
```bash
#!/bin/bash
# Daily health check - runs every 6 hours

echo "=== ChatekClaw Health Check $(date) ==="

# System resources
echo "CPU: $(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" )%"
echo "Memory: $(free -m | awk '/Mem/{print $3}')MB used"
echo "Disk: $(df -h / | awk '{print $5}' | tail -1) used"

# Service status
echo "Tuwunel: $(systemctl is-active tuwunel)"
echo "MAS: $(docker ps -q -f name=mas)"
echo "HedgeDoc: $(docker ps -q -f name=hedgedoc)"
echo "ZeroClaw: $(systemctl is-active zeroclaw)"
echo "BabyClaw: $(systemctl is-active babyclaw)"
echo "Cloudflared: $(systemctl is-active cloudflared)"

# Endpoint checks
curl -f http://localhost:8008/_matrix/client/versions > /dev/null 2>&1 && echo "Tuwunel endpoint: OK" || echo "Tuwunel endpoint: FAIL"
curl -f http://localhost:8080/.well-known/openid-configuration > /dev/null 2>&1 && echo "MAS endpoint: OK" || echo "MAS endpoint: FAIL"
curl -f http://localhost:3000 > /dev/null 2>&1 && echo "HedgeDoc endpoint: OK" || echo "HedgeDoc endpoint: FAIL"
```

### Alert Script Template
```bash
#!/bin/bash
# Alert to ClawPapa via Matrix DM

send_alert() {
    local level=$1
    local message=$2
    
    # Send alert via BabyClaw-Bot to ClawPapa's Matrix DM
    echo "[ALERT $level] $(date): $message"
    
    # Future: Integrate with Matrix API to send DM
    # curl -X POST "http://localhost:8008/_matrix/client/r0/rooms/ROOM_ID/send/m.room.message" ...
}

# Example usage
# send_alert "CRITICAL" "Tuwunel service down for > 1 minute"
# send_alert "WARNING" "Memory usage at 80%"
```

---

## Monitoring Integration

### Metrics to Track
- **System**: CPU, memory, disk, network I/O
- **Services**: Response time, error rate, request count
- **Security**: Auth attempts, failed logins, certificate expiry
- **Users**: Active users, registrations, engagement metrics
- **Business**: Uptime percentage, incident count, resolution time

### Reporting Schedule
- **Daily**: Automated health check log (stored in memory/)
- **Weekly**: Status report to ClawPapa via Matrix DM
- **Monthly**: Comprehensive operational review document in HedgeDoc
- **Quarterly**: Strategic alignment review with ClawPapa and Chance

---

## Incident Response Integration

When heartbeat detects an issue:
1. **Log the event** in daily memory file with timestamp
2. **Assess severity** using P0-P3 scale (see AGENTS.md)
3. **Execute response** based on runbook in TOOLS.md
4. **Alert ClawPapa** if P0 or P1 severity
5. **Document resolution** in incident log
6. **Update procedures** in TOOLS.md if new pattern discovered

---

## Maintenance Windows

**Scheduled Windows**:
- Weekly: Sunday 02:00-04:00 UTC (low traffic)
- Monthly: 1st of month 03:00-05:00 UTC
- Emergency: As needed with ClawPapa approval

**During Maintenance**:
- Alert users via Matrix announcement
- Create LXC snapshot before changes
- Monitor services during restart
- Verify all services return to healthy state
- Update documentation with changes made

---

*This heartbeat ensures the ship keeps flying smoothly. Every check is a chance to catch issues early and maintain operational excellence.*

*Last updated: 2025-01-14 by BabyClaw*
*Next review: After Phase 1 deployment complete*