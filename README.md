# Openclaw Bootstrap

One-command deployment for [Openclaw](https://github.com/openclaw/openclaw) — on bare metal or Docker.

## Docker Deployment (Recommended for NAS/Containers)

### Quick Start

```bash
# Clone
git clone https://github.com/nineunderground/openclaw-bootstrap.git
cd openclaw-bootstrap

# Configure
cp .env.example .env
nano .env  # Add your ANTHROPIC_API_KEY and other keys

# Build and run
docker-compose --profile oauth2 up -d
```


### Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `ANTHROPIC_API_KEY` | Yes | — | Your Anthropic API key |
| `CLAWDBOT_GATEWAY_PORT` | No | `4001` | Gateway port |
| `CLAWDBOT_GATEWAY_TOKEN` | No | auto-generated | Auth token for secure access |
| `TELEGRAM_BOT_TOKEN` | No | — | Telegram bot token from @BotFather |
| `OLLAMA_BASE_URL` | No | — | Ollama API URL (e.g., `http://192.168.1.100:11434/v1`) |
| `GITHUB_PAT` | No | — | GitHub Personal Access Token for git push/clone |
| `CLAWDBOT_REGENERATE_CONFIG` | No | — | Set to `1` to regenerate config on restart |

### Persistent Data

The container uses two volumes:
- `openclaw-data` → `/root/clawd` (workspace, memory, files)
- `openclaw-config` → `/root/.openclaw` (configuration, state)

### Local LLM with Ollama

Openclaw supports local LLMs via [Ollama](https://ollama.ai/). To use:

1. **Install Ollama** on a machine with a good GPU (or CPU for smaller models)
2. **Pull models** you want to use:
   ```bash
   ollama pull kimi-k2.5:cloud
   ollama pull qwen3-coder-next
   ```
3. **Update `.env`** with your Ollama URL:
   ```bash
   OLLAMA_BASE_URL=http://your-ollama-host:11434/v1
   ```
4. **Switch models** via Telegram:
   ```
   /model kimi      # Use kimi-k2.5:cloud
   /model qwen      # Use qwen3-coder-next
   /model default   # Back to Claude
   ```

The `config.example.json` includes pre-configured aliases for these models.

> **Note:** Ollama must be accessible from the Docker container. Use the host IP, not `localhost`, if running on a different machine.

### View Logs

```bash
docker logs -f openclaw-agent-service
```

### First Run Token

On first run, if you don't provide `CLAWDBOT_GATEWAY_TOKEN`, one is auto-generated and printed to the logs:

```bash
docker logs openclaw-agent-service | grep "GATEWAY TOKEN"
```

**Save this token!** You'll need it to access the gateway securely.

---

## OAuth2 Proxy (GitHub Authentication)

Protect your Openclaw Control UI behind GitHub login using [oauth2-proxy](https://oauth2-proxy.github.io/oauth2-proxy/).

### Architecture

```
Internet → Reverse Proxy (SSL) → oauth2-proxy (:4180) → Openclaw (:4001)
                                  (GitHub OAuth)          (internal)
```

### Step 1: Create a GitHub OAuth App

1. Go to **https://github.com/settings/developers**
2. Click **"New OAuth App"**
3. Fill in:

| Field | Value |
|-------|-------|
| Application name | `Openclaw` |
| Homepage URL | `https://your-domain.com` |
| Authorization callback URL | `https://your-domain.com/oauth2/callback` |

4. Click **Register application**
5. Copy the **Client ID** and generate a **Client Secret**

### Step 2: Configure

Edit your `.env` file:

```bash
# GitHub OAuth App credentials
GITHUB_CLIENT_ID=your-client-id
GITHUB_CLIENT_SECRET=your-client-secret

# Generate cookie secret: openssl rand -hex 16
OAUTH2_COOKIE_SECRET=your-cookie-secret

# Redirect URL (must match GitHub OAuth App callback URL)
OAUTH2_REDIRECT_URL=https://your-domain.com/oauth2/callback

# GitHub username allowed to access
GITHUB_ALLOWED_USER=your-github-username
```

### Step 3: Run

```bash
# Start both Openclaw and oauth2-proxy
docker-compose --profile oauth2 up -d
```

### Step 4: Point your reverse proxy

Update your reverse proxy (FRP/nginx/Caddy) to forward traffic to **port 4180** (oauth2-proxy) instead of 4001:

```
your-domain.com → Reverse Proxy (SSL) → :4180 (oauth2-proxy) → :4001 (Openclaw)
```

### Access Restriction

By default, **any GitHub user can log in**. Restrict access using one or more of these options:

#### Option 1: Restrict by GitHub username (recommended)

In `.env`:
```bash
GITHUB_ALLOWED_USER=nineunderground
```

Multiple users (comma-separated):
```bash
GITHUB_ALLOWED_USER=nineunderground,another-user
```

#### Option 2: Restrict by GitHub organization

Only members of a specific GitHub org can access:
```bash
GITHUB_ALLOWED_ORG=your-org-name
```

#### Option 3: Restrict by GitHub org + team

Only members of a specific team within an org:
```bash
GITHUB_ALLOWED_ORG=your-org-name
GITHUB_ALLOWED_TEAM=your-team-name
```

#### Option 4: Restrict by email allowlist

Edit `allowed-emails.txt` with one email per line:
```
PUT-YOUR-EMAIL-HERE
```

The file is mounted automatically into the oauth2-proxy container.

> **Important:** Do NOT set `OAUTH2_PROXY_EMAIL_DOMAINS=*` — it overrides the email file and allows everyone.

> **Note:** You can combine options. For example, restrict by username AND email for double verification.

### OAuth2 Proxy Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `GITHUB_CLIENT_ID` | Yes | — | GitHub OAuth App Client ID |
| `GITHUB_CLIENT_SECRET` | Yes | — | GitHub OAuth App Client Secret |
| `OAUTH2_COOKIE_SECRET` | Yes | — | Cookie encryption secret (`openssl rand -hex 16`) |
| `OAUTH2_REDIRECT_URL` | Yes | — | Must match GitHub callback URL |
| `GITHUB_ALLOWED_USER` | No | — | Restrict by GitHub username(s), comma-separated |
| `GITHUB_ALLOWED_ORG` | No | — | Restrict by GitHub organization |
| `GITHUB_ALLOWED_TEAM` | No | — | Restrict by GitHub team (requires org) |
| `OAUTH2_EMAILS_FILE` | No | — | Path to allowed emails file |
| `OAUTH2_PROXY_PORT` | No | `4180` | OAuth2 proxy port |

### Flow

1. User opens `https://your-domain.com`
2. oauth2-proxy redirects to GitHub login
3. GitHub authenticates → redirects back
4. oauth2-proxy verifies the GitHub username → forwards traffic to Openclaw
5. Openclaw gateway token is still required on first browser visit (`?token=...`)

### Troubleshooting

**404 after login:**
- Check oauth2-proxy can reach Openclaw: `docker logs openclaw-proxy`
- Both containers must be on the same Docker network (`openclaw-net`)

**WebSocket issues:**
- Ensure your reverse proxy passes `Upgrade` and `Connection` headers

**Wrong callback URL:**
- The `OAUTH2_REDIRECT_URL` must exactly match the callback URL in your GitHub OAuth App settings

---

## Bare Metal Deployment (VPS/Server)

### Quick Start

```bash
git clone https://github.com/nineunderground/openclaw-bootstrap.git
cd openclaw-bootstrap

# Create config
cp config.example.json config.json
nano config.json  # Edit with your values

# Deploy
sudo ./deploy.sh config.json
```

### Config File

```json
{
  "workspace": "/root/clawd",
  "gateway": {
    "port": 18181,
    "token": "your-secure-token"
  },
  "telegram": {
    "botToken": "from-botfather"
  },
  "anthropic": {
    "apiKey": "sk-ant-..."
  }
}
```

### What It Does

1. ✅ Installs Node.js 22 (if needed)
2. ✅ Installs Openclaw globally via official installer
3. ✅ Creates workspace directory
4. ✅ Generates Openclaw config from your JSON
5. ✅ Sets up systemd service with auto-restart
6. ✅ Starts the gateway

---

## Management Commands

### Docker

```bash
# Status
docker ps | grep openclaw

# Logs
docker logs -f openclaw-agent-service

# Restart
docker restart openclaw-agent-service

# Stop
docker stop openclaw-agent-service

# Shell into container
docker exec -it openclaw-agent-service bash

# Run openclaw CLI inside container
docker exec openclaw-agent-service openclaw status
docker exec openclaw-agent-service openclaw pairing list telegram
```

### Bare Metal (systemd)

```bash
openclaw status
journalctl -u openclaw-agent-service -f
systemctl restart openclaw-agent-service
```

---

## Telegram Pairing

After deployment, DM your Telegram bot. You'll receive a pairing code.

**Docker:**
```bash
docker exec openclaw-agent-service openclaw pairing list telegram
docker exec openclaw-agent-service openclaw pairing approve telegram <CODE>
```

**Bare metal:**
```bash
openclaw pairing list telegram
openclaw pairing approve telegram <CODE>
```

---

## Security

- Always set `CLAWDBOT_GATEWAY_TOKEN` before exposing to the internet
- Use OAuth2 proxy for web UI access control (see above)
- Use [openclaw-nginx-proxy-docker](https://github.com/nineunderground/openclaw-nginx-proxy-docker) for HTTPS
- Keep your API keys and tokens secure

---

## Related

- [Openclaw](https://github.com/openclaw/openclaw) — The AI assistant platform
- [openclaw-nginx-proxy-docker](https://github.com/nineunderground/openclaw-nginx-proxy-docker) — HTTPS reverse proxy
- [Openclaw Docs](https://docs.molt.bot) — Official documentation

## License

MIT
