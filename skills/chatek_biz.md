# Chatek.co Project: The Claw-Driven Marketplace

## 1. The Skill Marketplace Architecture

The ecosystem functions as a "Trust-as-a-Service" platform for vertical AI skills.

| Component | Role | Protocol/Stack |
|-----------|------|----------------|
| ZeroClaw / ClawPapa | The Execution Engine | Rust / Matrix / Workspace |
| Open-Skill Registry | Discovery Layer | clawhub.ai / openskills.besoeasy.com |
| skills.chatek.co | Sandbox & Audit Vault | LXC Isolation / Manual Audit Pipeline |
| tikoWallet | Settlement & Billing | A2A & x402 (HTTP 402) |
| Partner Orgs | Professional Auditors | Verified Subject Matter Experts (SMEs) |

---

## 2. The "Audit-to-Unlock" Workflow

To prevent supply chain attacks and data exfiltration, un-audited skills are never directly injected into a user's production workspace.

### Workflow Steps

1. **Pull & Cache**: When a user identifies a skill on clawhub.ai, it is pulled into a Sandboxed LXC at skills.chatek.co.

2. **Static & Dynamic Analysis**:
   - **Static**: Automated scanning for malicious bash commands or hidden IDENTITY.md exfiltration triggers.
   - **Dynamic**: The skill is executed in a "no-network" container to observe its behavior.

3. **Professional Audit**: Partner organizations (SMEs) review the SKILL.md and associated scripts for logic accuracy and "Soul" alignment.

4. **Verification Stamp**: Once passed, the skill is cryptographically signed and moved to the "Audited" tier.

5. **Subscription Unlock**: Users paying the Chatek Verification Subscription get instant access to the library of audited skills.

---

## 3. Agentic Resource Accounting (tikoWallet)

tikoWallet manages the complex financial flow between four parties:

- **The Developer**: Earns a royalty for the skill usage.
- **The Auditor**: Earns a "Verification Fee" from the subscription pool or per-audit.
- **The Platform (Chatek)**: Collects a facilitation fee via x402.
- **The User**: Pays a predictable subscription for "Safe Intelligence."

---

## 4. Business Model: The Verification Subscription

Instead of selling individual skills (which leads to fragmentation), Chatek.co operates a Tiered Security Model:

- **Community Tier**: Access to raw, un-audited skills (User assumes all risk).
- **Professional Tier**: Access to all "Audited & Tested" skills + Insurance/Liability protection.
- **Enterprise Tier**: Custom auditing for proprietary vertical skills (e.g., internal company logistics).

---

## 5. VCCBase Implementation (Safety for Kids)

For the VCCBase project, the "Claw" is hard-locked to ONLY pull from the skills.chatek.co audited repository. This ensures that no malicious "Skill" can ever interact with a minor's private MEMORY.md.