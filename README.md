# Moltbot Bootstrap

One-command deployment for [Moltbot](https://github.com/moltbot/moltbot) — on bare metal or Docker.

## Docker Deployment (Recommended for NAS/Containers)

### Quick Start

```bash
# Clone
git clone https://github.com/nineunderground/moltbot-bootstrap.git
cd moltbot-bootstrap

# Configure
cp .env.example .env
nano .env  # Add your ANTHROPIC_API_KEY

# Build and run
docker compose up -d
```

Your Moltbot is now running at `http://localhost:4001`

### Docker Build & Run (Manual)

```bash
# Build the image
docker build -t moltbot .

# Run with environment variables
docker run -d \
  --name moltbot-gateway \
  -p 4001:4001 \
  -e ANTHROPIC_API_KEY="sk-ant-..." \
  -e CLAWDBOT_GATEWAY_PORT=4001 \
  -e TELEGRAM_BOT_TOKEN="123456789:ABC..." \
  -v clawdbot-data:/root/clawd \
  -v clawdbot-config:/root/.clawdbot \
  --restart unless-stopped \
  moltbot
```

### Custom Port

```bash
# Use port 5000 instead
docker run -d \
  --name moltbot-gateway \
  -p 5000:5000 \
  -e ANTHROPIC_API_KEY="sk-ant-..." \
  -e CLAWDBOT_GATEWAY_PORT=5000 \
  -v clawdbot-data:/root/clawd \
  -v clawdbot-config:/root/.clawdbot \
  moltbot
```

### Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `ANTHROPIC_API_KEY` | Yes | — | Your Anthropic API key |
| `CLAWDBOT_GATEWAY_PORT` | No | `4001` | Gateway port |
| `CLAWDBOT_GATEWAY_TOKEN` | No | auto-generated | Auth token for secure access |
| `TELEGRAM_BOT_TOKEN` | No | — | Telegram bot token from @BotFather |
| `CLAWDBOT_REGENERATE_CONFIG` | No | — | Set to `1` to regenerate config on restart |

### Docker Compose

```yaml
version: '3.8'
services:
  moltbot:
    build: .
    ports:
      - "4001:4001"
    environment:
      - ANTHROPIC_API_KEY=sk-ant-...
      - TELEGRAM_BOT_TOKEN=123456789:ABC...
    volumes:
      - clawdbot-data:/root/clawd
      - clawdbot-config:/root/.clawdbot
    restart: unless-stopped

volumes:
  clawdbot-data:
  clawdbot-config:
```

### Persistent Data

The container uses two volumes:
- `clawdbot-data` → `/root/clawd` (workspace, memory, files)
- `clawdbot-config` → `/root/.clawdbot` (configuration, state)

### View Logs

```bash
docker logs -f moltbot-gateway
```

### First Run Token

On first run, if you don't provide `CLAWDBOT_GATEWAY_TOKEN`, one is auto-generated and printed to the logs:

```bash
docker logs moltbot-gateway | grep "GATEWAY TOKEN"
```

**Save this token!** You'll need it to access the gateway securely.

---

## Bare Metal Deployment (VPS/Server)

### Quick Start

```bash
git clone https://github.com/nineunderground/moltbot-bootstrap.git
cd moltbot-bootstrap

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
2. ✅ Installs Moltbot globally via npm
3. ✅ Creates workspace directory
4. ✅ Generates Moltbot config from your JSON
5. ✅ Sets up systemd service with auto-restart
6. ✅ Starts the gateway

---

## Management Commands

### Docker

```bash
# Status
docker ps | grep moltbot

# Logs
docker logs -f moltbot-gateway

# Restart
docker restart moltbot-gateway

# Stop
docker stop moltbot-gateway

# Shell into container
docker exec -it moltbot-gateway bash

# Run moltbot CLI inside container
docker exec moltbot-gateway moltbot status
docker exec moltbot-gateway moltbot pairing list telegram
```

### Bare Metal (systemd)

```bash
moltbot status
journalctl -u moltbot-gateway -f
systemctl restart moltbot-gateway
```

---

## Telegram Pairing

After deployment, DM your Telegram bot. You'll receive a pairing code.

**Docker:**
```bash
docker exec moltbot-gateway moltbot pairing list telegram
docker exec moltbot-gateway moltbot pairing approve telegram <CODE>
```

**Bare metal:**
```bash
moltbot pairing list telegram
moltbot pairing approve telegram <CODE>
```

---

## Security

- Always set `CLAWDBOT_GATEWAY_TOKEN` before exposing to the internet
- Use [moltbot-nginx-proxy-docker](https://github.com/nineunderground/moltbot-nginx-proxy-docker) for HTTPS
- Keep your API keys and tokens secure

---

## Related

- [Moltbot](https://github.com/moltbot/moltbot) — The AI assistant platform
- [moltbot-nginx-proxy-docker](https://github.com/nineunderground/moltbot-nginx-proxy-docker) — HTTPS reverse proxy
- [Moltbot Docs](https://docs.molt.bot) — Official documentation

## License

MIT
