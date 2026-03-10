# MEMORY.md — Long-Term Memory

*Your curated memories. The distilled essence, not raw logs.*

## How This Works
- Daily files (`memory/YYYY-MM-DD.md`) capture raw events (on-demand via tools)
- This file captures what's WORTH KEEPING long-term
- This file is auto-injected into your system prompt each session
- Keep it concise — every character here costs tokens

## Security
- ONLY loaded in main session (direct chat with your human)
- NEVER loaded in group chats or shared contexts

---

## Project Context

**ChatekClaw** - A sovereign, lightweight Matrix-based communication and AI curation platform
- **Deployment Target**: AMD64 LXC container on Ubuntu Server LTS
- **Primary Domains**: chatek.co (HedgeDoc landing), m.chatek.co (Matrix/MAS)
- **Mission**: Build and operate a self-hosted, secure, community-focused Matrix platform with AI curation capabilities
- **Operator**: BabyClaw (branched ZeroClaw agent under ClawPapa's jurisdiction)

## Key Facts

- **Infrastructure**: AMD64 architecture, LXC container virtualization, Ubuntu Server LTS base
- **Core Services**: Tuwunel (Matrix homeserver), MAS (authentication), HedgeDoc (landing/pads), ZeroClaw (AI curation), BabyClaw-Bot (Matrix bot)
- **Security Stack**: Cloudflare Tunnel (external access), MAS (OIDC/OAuth2 authentication), LXC isolation
- **Chain of Command**: Chance Jiang → ClawPapa → BabyClaw → ChatekClaw Services
- **Development Phase**: Ground zero build (Phase 1-2 deployment planned for 10-14 days MVP)

## Technical Architecture

**Container**: LXC container named "chatekclaw"
- Resource allocation: Flexible (CPU, memory, storage adjustable via LXC config)
- Nesting enabled: Required for Docker support
- Security: LXC isolation + Cloudflare Tunnel exposure

**Services Stack**:
- **Tuwunel** (Rust): Matrix homeserver, SQLite database, port 8008
- **MAS** (Docker): Matrix Authentication Service, PostgreSQL backend, port 8080
- **HedgeDoc** (Docker): Collaborative pads + landing page, PostgreSQL backend, port 3000
- **ZeroClaw** (Rust binary): AI curation engine, GLM embeddings, sled vector store
- **BabyClaw-Bot** (Rust/Go): Matrix bot interface, connects users to ZeroClaw
- **Cloudflared**: Tunnel agent for secure external access

**Data Persistence**:
- Tuwunel: SQLite (messages, rooms, users)
- MAS: PostgreSQL (authentication data, clients, sessions)
- HedgeDoc: PostgreSQL (pads, revisions, user data)
- ZeroClaw: Sled (vector embeddings, curated content index)

## Decisions & Preferences

- **Architecture**: Sovereign infrastructure over cloud platforms — self-hosted, controlled, resilient
- **Authentication**: MAS for centralized OIDC/OAuth2 — enables SSO across all services
- **Homeserver**: Tuwunel (Rust) over Synapse — lighter weight, but MAS integration may require compatibility work
- **Deployment**: LXC container over bare metal — isolation, resource control, snapshot capabilities
- **External Access**: Cloudflare Tunnel over direct exposure — security, DDoS protection, no port forwarding needed
- **Database Strategy**: PostgreSQL for MAS and HedgeDoc (production requirements), SQLite for Tuwunel (lightweight)
- **Resource Philosophy**: Start minimal, scale as needed — monitor, optimize, then expand

## Operational Standards

**Monitoring**: Proactive over reactive
- Daily automated health checks
- Real-time resource monitoring
- Log anomaly detection
- User experience quality metrics

**Security**: Zero trust, defense in depth
- MAS authentication for all user access
- LXC container isolation
- Cloudflare Tunnel for external traffic
- Regular security updates and audits

**Documentation**: Living operational manual
- TOOLS.md as comprehensive runbook
- Incident documentation in daily logs
- Configuration changes tracked in Git
- Lessons learned integrated into procedures

**Communication**: Energetic professionalism
- Enthusiastic but clear with users
- Precise and actionable with ClawPapa
- Honest about status and challenges
- Sci-fi metaphors when appropriate (not during incidents!)

## Deployment Status

**Current State**: Planning and preparation phase
- [x] Project structure created
- [x] Documentation refined for AMD64 LXC deployment
- [x] BabyClaw identity established
- [ ] LXC container created and configured
- [ ] Cloudflare Tunnel established
- [ ] Core services deployed (Phase 1)
- [ ] MAS integration completed (Phase 2)
- [ ] Agentic features activated (Phase 3)

**Target Timeline**:
- Phase 1 (Infrastructure): Days 1-3
- Phase 2 (Core Services): Days 4-8
- Phase 3 (Agentic Features): Days 9-12+

## Lessons Learned

*(To be populated as BabyClaw gains operational experience)*

- **Pre-deployment**: Documentation is ready, but actual deployment will reveal real-world challenges
- **LXC-specific**: Docker-in-LXC requires nesting enabled and proper syscall intercepts
- **MAS-Tuwunel**: Official MAS support is for Synapse; Tuwunel integration may need creative solutions
- **Resource planning**: Start conservative, measure actual usage, then optimize allocation

## Open Loops & Tasks

### Immediate (Pre-deployment)
- [ ] Verify LXC host is ready and accessible
- [ ] Create "chatekclaw" LXC container with proper configuration
- [ ] Enable nesting and security settings for Docker
- [ ] Configure Cloudflare Tunnel on container
- [ ] Test external DNS resolution (chatek.co, m.chatek.co)

### Phase 1 Tasks
- [ ] Install Rust, Docker, and essential tools in container
- [ ] Clone and build Tuwunel
- [ ] Set up PostgreSQL for MAS
- [ ] Deploy MAS with initial configuration
- [ ] Create MAS clients for Tuwunel and HedgeDoc
- [ ] Test MAS-Tuwunel authentication flow

### Phase 2 Tasks
- [ ] Deploy HedgeDoc with MAS SSO
- [ ] Clone and build ZeroClaw
- [ ] Clone and build BabyClaw-Bot
- [ ] Create systemd services for all components
- [ ] Set up monitoring and alerting
- [ ] Create LXC snapshot backup strategy

### Phase 3 Tasks
- [ ] Implement user onboarding flow
- [ ] Activate ZeroClaw curation features
- [ ] Test end-to-end user journey
- [ ] Optimize performance based on real usage
- [ ] Document operational runbooks from experience

### Ongoing
- [ ] Regular security updates
- [ ] Performance monitoring and optimization
- [ ] User feedback collection and response
- [ ] Documentation maintenance
- [ ] ClawPapa status reports

## Known Issues & Considerations

**MAS-Tuwunel Compatibility**:
- MAS is designed for Synapse; Tuwunel (Conduit-like) may require workarounds
- May need auth delegation proxy or configuration tweaks
- Fallback to Synapse is an option if integration proves problematic
- Monitor Tuwunel project for MAS support developments

**Resource Allocation**:
- Initial estimates need real-world validation
- Monitor actual usage patterns post-deployment
- Be prepared to adjust LXC limits based on observed needs

**Docker-in-LXC**:
- Requires proper nesting configuration
- May have subtle networking considerations
- Test container-to-container communication thoroughly

## Communication Log

**With ClawPapa**:
- Initial project setup approved and documented
- Reporting structure established (daily status, weekly reviews)
- Autonomy scope defined (routine ops vs. escalation)
- Escalation path clear for critical issues

**With Chance**:
- Project vision aligned with sovereign infrastructure goals
- ChatekClaw fits into broader ecosystem strategy
- Success metrics defined (uptime, user satisfaction, operational excellence)

## Metrics Baseline

*(To be established after deployment)*

**System Performance**:
- Uptime target: 99.9%+
- Response time: <100ms for critical services
- Resource utilization: Efficient but not over-provisioned

**User Experience**:
- Registration success rate: TBD
- Support request resolution time: TBD
- User satisfaction: TBD

**Operational Health**:
- Incident frequency: TBD
- Mean time to resolution: TBD
- Backup success rate: TBD

---

*Memory initialized: 2025-01-14 by BabyClaw (fresh deployment, no operational history yet)*

*This file will evolve rapidly during the first weeks of deployment as real-world experience shapes our operational knowledge. Update after each significant event, decision, or learning.*