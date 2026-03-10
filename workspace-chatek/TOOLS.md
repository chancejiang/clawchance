# ChatekClaw - TOOLS.md

## Project Overview

ChatekClaw is a sovereign, lightweight Matrix-based communication and AI curation platform designed to run on AMD64 infrastructure within an LXC container on Ubuntu Server LTS. This document outlines the complete architecture and implementation plan with full MAS (Matrix Authentication Service) integration.

---

## Refined Architecture Overview

- **ZeroClaw** (~3-5 MB Rust binary): AI brain for agentic curation (GLM embeddings, local sled vector search, digest generation, notifications).
- **Tuwunel** (Rust Matrix homeserver): Core messaging/identity.
- **MAS** (Docker, ~100-200 MB): Authentication service for OIDC/SSO, enabling secure logins across services (e.g., HedgeDoc).
- **BabyClaw** (Rust/Go gateway): Bot for Tammy interactions, relaying to ZeroClaw.
- **Tammy** (Matrix client): User app (mobile + web sidecar) for chats.
- **HedgeDoc** (Docker): chatek.co landing + pads for long outputs.
- **Cloudflare Tunnel**: Secure exposure for https://m.chatek.co (Matrix/MAS) and https://chatek.co (HedgeDoc).
- **Data Flow**: Users sign up via Tuwunel + MAS → auth in Tammy → chat with BabyClaw → ZeroClaw curates → outputs to HedgeDoc pads.

### Deployment Environment

- **Platform**: AMD64 (x86_64) architecture
- **Virtualization**: LXC container
- **Host OS**: Ubuntu Server LTS (latest)
- **Container OS**: Ubuntu LTS (matching host or as preferred)
- **Resource Allocation**: Defined via LXC configuration (flexible, scalable)

### Key Integration Notes

- MAS runs as a Docker sidecar alongside Tuwunel (Rust-based homeserver)
- Official MAS support is primarily for Synapse; integration with Tuwunel (Conduit-like) may require compatibility checks
- Ensure Tuwunel exposes necessary auth delegation endpoints
- Fallback to Synapse available if Tuwunel integration issues arise
- Everything exposed via Cloudflare Tunnel for secure, sovereign deployment
- LXC container provides isolation while maintaining near-native performance on AMD64

---

## Step-by-Step Build Plan (Ground Zero)

**Total Effort**: 10-14 days for MVP  
**Target Platform**: AMD64 LXC Container on Ubuntu Server LTS

### Phase 1: Infrastructure & Exposure (Days 1-3)

#### 1. Prepare LXC Container & Domains

**LXC Container Setup:**

```bash
# On LXC host, create container (if not already created)
lxc launch ubuntu:22.04 chatekclaw

# Or if using Ubuntu 24.04 LTS:
lxc launch ubuntu:24.04 chatekclaw

# Configure container resources (adjust as needed)
lxc config set chatekclaw limits.cpu 2
lxc config set chatekclaw limits.memory 4GB

# Enable nesting for Docker support
lxc config set chatekclaw security.nesting true
lxc config set chatekclaw security.syscalls.intercept.mknod true

# Restart container to apply changes
lxc restart chatekclaw

# Enter container shell
lxc shell chatekclaw
```

**System Setup (inside LXC container):**
```bash
# Update system
apt update && apt upgrade -y

# Install essential packages
apt install -y curl wget git build-essential pkg-config libssl-dev

# Install Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source $HOME/.cargo/env

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
usermod -aG docker $USER

# Install Docker Compose (if not included)
apt install -y docker-compose-plugin

# Verify installations
rustc --version
docker --version
docker compose version
```

**Domain Configuration:**
- Primary: chatek.co
- Matrix/MAS: m.chatek.co
- Configure both in Cloudflare DNS

#### 2. Setup Cloudflare Tunnel

**Installation:**
```bash
# Download AMD64 binary from GitHub
wget https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64
chmod +x cloudflared-linux-amd64
mv cloudflared-linux-amd64 /usr/local/bin/cloudflared

# Verify installation
cloudflared --version
```

**Tunnel Creation:**
1. Create tunnel in Cloudflare Dashboard
2. Note the tunnel UUID

**Configuration (`~/.cloudflared/config.yml`):**
```yaml
tunnel: chatekclaw-tunnel
credentials-file: /home/chance/.cloudflared/<tunnel-uuid>.json
ingress:
  - hostname: chatek.co
    service: http://localhost:3000  # HedgeDoc
  - hostname: m.chatek.co
    service: http://localhost:8008  # Tuwunel + MAS proxy
  - service: http_status:404
```

**DNS Setup:**
- Create CNAMEs pointing to `<tunnel-uuid>.cfargotunnel.com`
- Run: `cloudflared tunnel run` (set up as systemd service)

**Systemd Service Setup:**
```bash
# Create systemd service
cat > /etc/systemd/system/cloudflared.service <<EOF
[Unit]
Description=Cloudflare Tunnel
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/cloudflared tunnel run
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Enable and start service
systemctl daemon-reload
systemctl enable cloudflared
systemctl start cloudflared
systemctl status cloudflared
```

**Important**: Ensure Tunnel has access to MAS endpoints (route MAS auth paths via Nginx if needed)

---

### Phase 2: Core Services with MAS Integration (Days 4-8)

#### 1. Tuwunel (Matrix Homeserver)

**Installation:**
```bash
# Clone Tuwunel repository
git clone https://github.com/matrix-construct/tuwunel
cd tuwunel
cargo build --release
```

**Configuration (`tuwunel.toml`):**
```toml
server_name = "m.chatek.co"
database = "sqlite://chatek.db"
# Federation optional for initial setup
bind_address = "127.0.0.1"
port = 8008

# Performance tuning for AMD64
max_request_size = 20000000  # 20 MB
allow_registration = true
allow_federation = false  # Enable later if needed
```

**Systemd Service:**
```bash
# Create systemd service for Tuwunel
cat > /etc/systemd/system/tuwunel.service <<EOF
[Unit]
Description=Tuwunel Matrix Homeserver
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/tuwunel
ExecStart=/opt/tuwunel/target/release/tuwunel
Restart=on-failure
RestartSec=5
Environment="RUST_LOG=info"

[Install]
WantedBy=multi-user.target
EOF

# Enable and start service
systemctl daemon-reload
systemctl enable tuwunel
systemctl start tuwunel
```

**Testing:**
```bash
curl http://localhost:8008/_matrix/client/versions
```

#### 2. MAS (Authentication Service)

**Prerequisites:**
- PostgreSQL required for production (not SQLite)
- Use Docker `postgres:16-alpine` image

**Docker Compose Setup (`/opt/chatekclaw/docker-compose.yml`):**
```yaml
services:
  mas-postgres:
    image: postgres:16-alpine
    container_name: mas-postgres
    environment:
      POSTGRES_USER: mas
      POSTGRES_PASSWORD: <strong-secret>
      POSTGRES_DB: mas
    volumes:
      - ./mas-data:/var/lib/postgresql/data
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U mas"]
      interval: 10s
      timeout: 5s
      retries: 5

  mas:
    image: ghcr.io/element-hq/matrix-authentication-service:latest
    container_name: mas
    depends_on:
      mas-postgres:
        condition: service_healthy
    environment:
      - DATABASE_URL=postgresql://mas:<secret>@mas-postgres/mas
      - RUST_LOG=info
    volumes:
      - ./mas-config:/etc/mas
    ports:
      - "8080:8080"
    restart: unless-stopped
```

**Configuration (`mas-config/config.yaml`):**
```yaml
# Generate secrets with: mas-cli generate secrets
http:
  listeners:
    - name: web
      resources:
        - name: discovery
        - name: human
        - name: oauth
        - name: compat
        - name: graphql
        - name: assets
      binds:
        - address: "0.0.0.0:8080"
      proxy_protocol: false

database:
  uri: "postgresql://mas:<secret>@mas-postgres/mas"

matrix:
  homeserver: "m.chatek.co"
  secret: "<generated-homeserver-secret>"
  endpoint: "http://host.docker.internal:8008"

# Email configuration (optional - integrate Resend API for digests)
email:
  from: "\"ChatekClaw Auth\" <noreply@chatek.co>"
  # SMTP or API-based configuration

# OIDC upstream providers (for MFA if needed)
upstream_oauth2:
  providers: []

# Branding (optional)
branding:
  human_name: "ChatekClaw Auth"
  service_name: "ChatekClaw"
```

**Initialize MAS:**
```bash
# Navigate to chatekclaw directory
cd /opt/chatekclaw

# Create necessary directories
mkdir -p mas-config mas-data

# Start PostgreSQL first
docker compose up -d mas-postgres

# Wait for PostgreSQL to be ready
sleep 10

# Generate secrets (run MAS container temporarily)
docker run --rm -v $(pwd)/mas-config:/etc/mas \
  ghcr.io/element-hq/matrix-authentication-service:latest \
  mas-cli generate secrets > mas-config/config.yaml

# Create client for Tuwunel
docker run --rm -v $(pwd)/mas-config:/etc/mas \
  --network container:mas \
  ghcr.io/element-hq/matrix-authentication-service:latest \
  mas-cli clients create \
  --client-id=tuwunel \
  --client-secret=<generated-secret> \
  --name="Tuwunel Homeserver"

# Verify setup
docker run --rm -v $(pwd)/mas-config:/etc/mas \
  --network container:mas \
  ghcr.io/element-hq/matrix-authentication-service:latest \
  mas-cli clients list

# Start all services
docker compose up -d
```

**Integration with Tuwunel:**
1. In Tuwunel config: Add auth delegation to MAS
   ```toml
   # Note: May need patch/proxy for Conduit-like homeservers
   oidc_provider = "http://localhost:8080"
   ```
2. In MAS config: Set `matrix.homeserver.endpoint` to Tuwunel's URL
3. Test authentication flow with curl

**Troubleshooting:**
- MAS requires PostgreSQL (not SQLite for production)
- Ensure secrets match between MAS and Tuwunel
- Debug with `RUST_LOG=debug`
- If Tuwunel-MAS compatibility issues arise, consider Synapse fallback
- Check Docker network connectivity: `docker network ls`, `docker network inspect`

#### 3. HedgeDoc (Landing + Pads)

**Add to `docker-compose.yml`:**
```yaml
  hedgedoc:
    image: nabo/hedgedoc:latest
    container_name: hedgedoc
    ports:
      - "3000:3000"
    environment:
      - CMD_DOMAIN=chatek.co
      - CMD_OAUTH2_PROVIDERNAME=Matrix
      - CMD_OAUTH2_CLIENT_ID=<mas-client-id-for-hedgedoc>
      - CMD_OAUTH2_CLIENT_SECRET=<secret>
      - CMD_OAUTH2_AUTHORIZATION_URL=http://host.docker.internal:8080/oauth2/authorize
      - CMD_OAUTH2_TOKEN_URL=http://host.docker.internal:8080/oauth2/token
      - CMD_OAUTH2_USER_PROFILE_URL=http://host.docker.internal:8080/userinfo
      - CMD_OAUTH2_SCOPE=openid profile email
      - CMD_ALLOW_ANONYMOUS=false
      - CMD_DB_URL=postgres://hedgedoc:<secret>@hedgedoc-postgres:5432/hedgedoc
    depends_on:
      - mas
      - hedgedoc-postgres
    restart: unless-stopped

  hedgedoc-postgres:
    image: postgres:16-alpine
    container_name: hedgedoc-postgres
    environment:
      POSTGRES_USER: hedgedoc
      POSTGRES_PASSWORD: <strong-secret>
      POSTGRES_DB: hedgedoc
    volumes:
      - ./hedgedoc-data:/var/lib/postgresql/data
    restart: unless-stopped
```

**Setup:**
```bash
# Create MAS client for HedgeDoc
docker run --rm -v $(pwd)/mas-config:/etc/mas \
  --network container:mas \
  ghcr.io/element-hq/matrix-authentication-service:latest \
  mas-cli clients create \
  --client-id=hedgedoc \
  --client-secret=<generated-secret> \
  --name="HedgeDoc" \
  --redirect-uri="https://chatek.co/auth/oauth2/callback"

# Start services
docker compose up -d
```

**Landing Page:**
- Create `/landing` pad with onboarding Markdown
- Include signup instructions and project overview

**Test SSO:**
1. Navigate to https://chatek.co
2. Click "Matrix login"
3. Should redirect to MAS → Tuwunel authentication
4. Return with authenticated session

#### 4. ZeroClaw (AI Runtime)

**Installation:**
```bash
# Clone ZeroClaw repository (adjust URL as needed)
git clone <zeroclaw-repo-url> /opt/zeroclaw
cd /opt/zeroclaw
cargo build --release
```

**Configuration:**
- GLM API integration for embeddings
- Local sled database for vector storage
- Tools for MAS auth validation (validate user tokens via MAS userinfo endpoint)

**Systemd Service:**
```bash
# Create systemd service for ZeroClaw
cat > /etc/systemd/system/zeroclaw.service <<EOF
[Unit]
Description=ZeroClaw AI Runtime
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/zeroclaw
ExecStart=/opt/zeroclaw/target/release/zeroclaw --daemon
Restart=on-failure
RestartSec=5
Environment="RUST_LOG=info"

[Install]
WantedBy=multi-user.target
EOF

# Enable and start service
systemctl daemon-reload
systemctl enable zeroclaw
systemctl start zeroclaw
```

**Key Features:**
- GLM embeddings for semantic search
- Sled vector store for local-first data
- Digest generation and notifications
- Integration with Matrix for alerts

#### 5. BabyClaw (Bot Gateway)

**Installation:**
```bash
# Clone BabyClaw repository (adjust URL as needed)
git clone <babyclaw-repo-url> /opt/babyclaw
cd /opt/babyclaw
cargo build --release
```

**Configuration:**
- Homeserver: `https://m.chatek.co`
- Auth via MAS delegation
- ZeroClaw socket connection
- Bot credentials (register via MAS)

**Systemd Service:**
```bash
# Create systemd service for BabyClaw
cat > /etc/systemd/system/babyclaw.service <<EOF
[Unit]
Description=BabyClaw Bot Gateway
After=network.target tuwunel.service zeroclaw.service

[Service]
Type=simple
User=root
WorkingDirectory=/opt/babyclaw
ExecStart=/opt/babyclaw/target/release/babyclaw
Restart=on-failure
RestartSec=5
Environment="RUST_LOG=info"

[Install]
WantedBy=multi-user.target
EOF

# Enable and start service
systemctl daemon-reload
systemctl enable babyclaw
systemctl start babyclaw
```

#### 6. Tammy (User-Facing Chat Client)

**Web Version Setup:**
Add to `docker-compose.yml` or serve static files:
```yaml
  tammy-web:
    image: <tammy-web-image>  # or use nginx for static files
    container_name: tammy-web
    ports:
      - "8081:80"
    environment:
      - HOMESERVER_URL=https://m.chatek.co
      - IDENTITY_SERVER_URL=https://m.chatek.co
    restart: unless-stopped
```

**Integration with HedgeDoc Landing:**
- Embed link or iframe to `chatek.co/tammy`
- Pre-configured with `m.chatek.co` homeserver

---

### Phase 3: Agentic Features & Polish (Days 9-12+)

#### 1. Onboarding Flow

**User Journey:**
1. User visits chatek.co landing (public HedgeDoc pad)
2. Reads onboarding documentation
3. Clicks "Sign up via Tammy"
4. Enters invite code (if required)
5. MAS handles registration via Tuwunel delegation
6. User gains access to Matrix messaging and ZeroClaw features

**Implementation:**
- Create inviting users via ZeroClaw tools
- Generate Matrix invite tokens
- Set up registration email flows (optional)

#### 2. Core Interaction Loop

**Workflow:**
```
User in Tammy
    ↓
Chat message sent
    ↓
BabyClaw receives (bot gateway)
    ↓
Routes to ZeroClaw (AI processing)
    ↓
ZeroClaw actions:
  - Embed content (GLM)
  - Search vector store (sled)
  - Generate response
  - Create HedgeDoc pad if needed
    ↓
Response to user:
  - Short reply in Matrix
  - Link to HedgeDoc pad (MAS-authenticated)
```

#### 3. Content Management

**Vibe Logs:**
- Long-form content stored in HedgeDoc pads
- ZeroClaw indexes all content:
  - Export Markdown from HedgeDoc
  - Generate GLM embeddings
  - Store in sled vector database
  - Enable semantic search and retrieval

**Data Persistence:**
- Tuwunel: SQLite database for messages
- MAS: PostgreSQL for auth data
- ZeroClaw: Sled for vectors and embeddings
- HedgeDoc: PostgreSQL for pads
- All data stored within LXC container (backup strategy recommended)

#### 4. Testing & Hardening

**End-to-End Testing:**
1. User signup via MAS
2. Authentication in Tammy
3. Send test message to BabyClaw
4. Verify ZeroClaw processing
5. Check HedgeDoc pad creation and access
6. Test SSO across all services

**Security Considerations:**
- E2EE in Matrix (where applicable)
- MAS for centralized auth and potential MFA
- Secure secrets management
- Regular security updates for all components
- Cloudflare Tunnel provides DDoS protection
- LXC container isolation provides additional security layer

**Monitoring:**
- MAS logs for authentication events: `docker logs mas`
- ZeroClaw alerts to Matrix DM
- Service health checks: `systemctl status <service>`
- Resource monitoring: `htop`, `docker stats`
- LXC container resource monitoring: `lxc info chatekclaw`

---

## LXC Container Management

### Container Operations

**Start/Stop/Restart:**
```bash
# From LXC host
lxc start chatekclaw
lxc stop chatekclaw
lxc restart chatekclaw
```

**Resource Management:**
```bash
# Adjust CPU limits
lxc config set chatekclaw limits.cpu 4

# Adjust memory limits
lxc config set chatekclaw limits.memory 8GB

# Adjust disk limits (if using LVM or ZFS)
lxc config set chatekclaw limits.disk 50GB
```

**Backup Strategy:**
```bash
# Snapshot container
lxc snapshot chatekclaw backup-$(date +%Y%m%d)

# Export container backup
lxc export chatekclaw chatekclaw-backup-$(date +%Y%m%d).tar.gz

# Schedule regular backups via cron
```

**Network Configuration:**
```bash
# View container IP
lxc list chatekclaw

# Port forwarding (if needed, though Cloudflare Tunnel handles this)
lxc config device add chatekclaw port8008 proxy listen=tcp:0.0.0.0:8008 connect=tcp:127.0.0.1:8008
```

---

## Built-in Tools Reference

This section maintains compatibility with the original workspace TOOLS.md structure.

- **shell** — Execute terminal commands
  - Use when: running local checks, build/test commands, or diagnostics
  - Don't use when: a safer dedicated tool exists, or command is destructive without approval

- **file_read** — Read file contents
  - Use when: inspecting project files, configs, or logs
  - Don't use when: you only need a quick string search (prefer targeted search first)

- **file_write** — Write file contents
  - Use when: applying focused edits, scaffolding files, or updating docs/code
  - Don't use when: unsure about side effects or when the file should remain user-owned

- **memory_store** — Save to memory
  - Use when: preserving durable preferences, decisions, or key context
  - Don't use when: info is transient, noisy, or sensitive without explicit need

- **memory_recall** — Search memory
  - Use when: you need prior decisions, user preferences, or historical context
  - Don't use when: the answer is already in current files/conversation

- **memory_forget** — Delete a memory entry
  - Use when: memory is incorrect, stale, or explicitly requested to be removed
  - Don't use when: uncertain about impact; verify before deleting

---

## Deployment Checklist

### Pre-Deployment
- [ ] LXC container created and configured (AMD64, Ubuntu LTS)
- [ ] Nesting enabled for Docker support
- [ ] Resource limits configured (CPU, memory, disk)
- [ ] Rust toolchain installed via rustup
- [ ] Docker and Docker Compose installed
- [ ] Domains configured in Cloudflare DNS
- [ ] Cloudflare Tunnel set up and tested

### Core Services
- [ ] Tuwunel built and configured
- [ ] PostgreSQL containers running (MAS + HedgeDoc)
- [ ] MAS configured and connected to Tuwunel
- [ ] MAS clients created for all services
- [ ] HedgeDoc running with MAS SSO
- [ ] ZeroClaw built and configured
- [ ] BabyClaw built and configured
- [ ] Tammy web client deployed

### Integration Testing
- [ ] User can register via MAS
- [ ] User can login to Tammy
- [ ] Messages route through BabyClaw to ZeroClaw
- [ ] HedgeDoc pads created with proper auth
- [ ] All services accessible via Cloudflare Tunnel
- [ ] SSO works across Matrix, MAS, and HedgeDoc

### Post-Deployment
- [ ] Monitoring and alerts configured
- [ ] Backup strategy implemented (LXC snapshots)
- [ ] Security audit completed
- [ ] Documentation updated
- [ ] Team trained on maintenance procedures

---

## Troubleshooting Guide

### Common Issues

**MAS won't start:**
- Check PostgreSQL connection: `docker logs mas-postgres`
- Verify secrets in config.yaml match database credentials
- Check port 8080 availability: `netstat -tulpn | grep 8080`
- Ensure Docker network connectivity: `docker network inspect bridge`

**Tuwunel-MAS integration fails:**
- Verify MAS is accessible: `curl http://localhost:8080/.well-known/openid-configuration`
- Check Tuwunel logs: `journalctl -u tuwunel -f`
- May need auth delegation proxy (check Tuwunel documentation)

**HedgeDoc SSO not working:**
- Verify MAS client configuration: `mas-cli clients list`
- Check redirect URIs match exactly
- Review HedgeDoc logs: `docker logs hedgedoc`
- Test OAuth flow manually with curl

**Cloudflare Tunnel issues:**
- Check tunnel status: `cloudflared tunnel list`
- Verify ingress rules in config.yml
- Check DNS resolution: `dig chatek.co`
- Review Cloudflare dashboard for errors

**Docker issues in LXC:**
- Verify nesting is enabled: `lxc config get chatekclaw security.nesting`
- Check Docker daemon: `systemctl status docker`
- Restart Docker: `systemctl restart docker`
- Check container logs: `docker logs <container-name>`

**Performance Issues:**
- Monitor resource usage: `htop`, `docker stats`
- Check LXC resource limits: `lxc config show chatekclaw`
- Increase limits if needed: `lxc config set chatekclaw limits.memory 8GB`
- Optimize ZeroClaw vector store size
- Consider using PostgreSQL for Tuwunel if SQLite becomes a bottleneck

**LXC Container Issues:**
- Container won't start: Check LXC logs on host
- Network connectivity: `lxc exec chatekclaw -- ping -c 3 google.com`
- Disk space: `lxc exec chatekclaw -- df -h`
- Process list: `lxc exec chatekclaw -- ps aux`

---

## AMD64 vs ARM64 Considerations

### Performance Advantages
- **AMD64**: Full x86_64 architecture with mature compiler optimizations
- **Docker Images**: All images have native AMD64 support (no emulation)
- **Rust Compilation**: Faster compile times on AMD64
- **Database Performance**: PostgreSQL performs better on AMD64

### Resource Expectations
- **ZeroClaw**: 50-100 MB RAM (more efficient than on ARM64)
- **Tuwunel**: 100-200 MB RAM
- **MAS**: 100-200 MB RAM
- **HedgeDoc**: 200-300 MB RAM
- **PostgreSQL**: 100-500 MB RAM (depending on data size)

### Optimization Tips
- Use `--release` flag for Rust builds
- Enable LTO (Link Time Optimization) in Cargo.toml for ZeroClaw
- Consider using jemalloc for memory-intensive services
- Use PostgreSQL connection pooling for MAS and HedgeDoc

---

## Next Steps

1. **Start with Phase 1**: Infrastructure setup and Cloudflare Tunnel
2. **Iterate through Phase 2**: Deploy services one at a time, testing each
3. **Complete Phase 3**: Add agentic features and polish UX
4. **Monitor and iterate**: Based on real usage patterns
5. **Scale resources**: Adjust LXC limits as needed based on actual usage

---

*This TOOLS.md serves as the comprehensive guide for the ChatekClaw project on AMD64 LXC infrastructure. Update as needed during development and deployment.*