# Skill: ZeroClaw System Provisioning (Beelink EQ13)

## 1. Hardware Context & Constraints

* **Host Device:** Beelink EQ13 (Small Form Factor)
* **CPU:** Intel Processor N100 (4 Cores, 4 Threads, up to 3.4GHz)
* **RAM:** 16GB DDR5 (Single Channel)
* **Storage:** 512GB M.2 NVMe SSD
* **Networking:** Dual 1GbE/2.5GbE LAN + Wi-Fi 6
* **Role:** Dedicated Gateway/Agent Node (External LLM Inference via GLM Coding Plan)

---

## 2. System Debloating & Optimization

The agent must minimize background resource consumption to ensure zero latency for OpenClaw logic.

### Skill: Windows 11 Slimming

* **Action:** Execute `iwr -useb https://christitus.com/win | iex` (or equivalent offline script).
* **Target:** * Disable Telemetry, Bing Search, and Cortana.
* Set Services to "Manual" for non-essential Windows features.
* Remove pre-installed UWP apps (News, Weather, Xbox).


* **Power Plan:** Set to "High Performance" to prevent CPU throttling during API bursts.

---

## 3. Environment Setup (OpenClaw Prerequisites)

### Skill: Dependency Management

* **Runtime:** Install **Node.js (LTS)** and **Python 3.11+**.
* **Process Manager:** Install **PM2** via npm for 24/7 uptime management.
* `npm install pm2 -g`


* **Containerization (Optional):** Install **LXD/LXC** if running via WSL2, or **Docker Desktop** (if required by specific agent tools).

---

## 4. Networking & Connectivity

### Skill: Secure Tunneling

* **Tailscale:** Install and authenticate to join the `proxtps` private mesh network.
* **API Gateway:** Optimize routing for `api.zhipuai.cn` to ensure minimal RTT (Round Trip Time) for the GLM Coding Plan.
* **Static Mapping:** Configure local DNS or HOSTS file for internal agent-to-agent communication.

---

## 5. OpenClaw Deployment Logic

### Skill: Instance Initialization

1. **Clone Repository:** Target directory `C:\OpenClaw`.
2. **Configuration:** * Inject API Keys for **GLM Coding Plan**.
* Configure `config.yaml` to point to external LLM endpoints.


3. **Persistence:** * `pm2 start index.js --name "openclaw-core"`
* `pm2 save`
* `pm2 startup` (Set to trigger on Windows boot).



---

## 6. Monitoring & Maintenance

### Skill: Health Checks

* **Memory Guard:** Monitor for memory leaks. If RAM usage exceeds 85%, trigger a graceful restart of the `openclaw-core` process.
* **Thermal Monitor:** Ensure CPU temperature remains below **75°C**. Since the EQ13 is fan-cooled, high temps indicate a need for task throttling.