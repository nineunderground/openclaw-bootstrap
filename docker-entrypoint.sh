#!/bin/bash
set -e

# Detect config dir (openclaw may use ~/.openclaw or ~/.openclaw depending on version)
if [ -d "/root/.openclaw" ] || command -v openclaw &>/dev/null && openclaw --help 2>&1 | grep -q "openclaw"; then
    CONFIG_DIR="/root/.openclaw"
    CONFIG_FILE="$CONFIG_DIR/openclaw.json"
else
    CONFIG_DIR="/root/.openclaw"
    CONFIG_FILE="$CONFIG_DIR/openclaw.json"
fi
WORKSPACE="/root/clawd"

# Ensure directories exist
mkdir -p "$CONFIG_DIR" "$WORKSPACE/memory"

# Also ensure alternate config dir exists (some versions check both)
mkdir -p /root/.openclaw /root/.openclaw

# Determine if Telegram is enabled
if [ -n "$TELEGRAM_BOT_TOKEN" ]; then
    TELEGRAM_ENABLED="true"
else
    TELEGRAM_ENABLED="false"
fi

# Determine Telegram DM policy and allowlist
if [ -n "$TELEGRAM_ALLOWED_USERS" ]; then
    TELEGRAM_DM_POLICY="allowlist"
    # Build JSON array from comma-separated user IDs
    TELEGRAM_ALLOW_FROM=$(echo "$TELEGRAM_ALLOWED_USERS" | sed 's/,/","/g' | sed 's/^/["/' | sed 's/$/"]/')
else
    TELEGRAM_DM_POLICY="pairing"
    TELEGRAM_ALLOW_FROM="[]"
fi

# Determine if Ollama is enabled
if [ -n "$OLLAMA_BASE_URL" ]; then
    OLLAMA_ENABLED="true"
else
    OLLAMA_ENABLED="false"
fi

# Configure GitHub PAT for git operations if provided
if [ -n "$GITHUB_PAT" ]; then
    GITHUB_ENABLED="true"
    # Configure git credential helper to use the PAT
    git config --global credential.helper store
    echo "https://${GITHUB_PAT}@github.com" > ~/.git-credentials
    chmod 600 ~/.git-credentials
    # Also set up .netrc for tools that use it
    echo "machine github.com login oauth password ${GITHUB_PAT}" > ~/.netrc
    chmod 600 ~/.netrc
else
    GITHUB_ENABLED="false"
fi

# Generate config if it doesn't exist or if env vars are set
if [ ! -f "$CONFIG_FILE" ] || [ -n "$openclaw_REGENERATE_CONFIG" ]; then
    echo "Generating openclaw configuration..."
    
    # Use provided token or generate one
    if [ -z "$openclaw_GATEWAY_TOKEN" ]; then
        GATEWAY_TOKEN=$(openssl rand -hex 32)
        TOKEN_GENERATED=1
    else
        GATEWAY_TOKEN="$openclaw_GATEWAY_TOKEN"
        TOKEN_GENERATED=0
    fi
    
    # Build config
    cat > "$CONFIG_FILE" << EOF
{
  "agents": {
    "defaults": {
      "workspace": "$WORKSPACE",
      "maxConcurrent": 4,
      "subagents": {
        "maxConcurrent": 8
      },
      "compaction": {
        "mode": "safeguard"
      }
    }
  },
  "gateway": {
    "port": ${openclaw_GATEWAY_PORT:-4001},
    "mode": "local",
    "bind": "lan",
    "auth": {
      "mode": "token",
      "token": "$GATEWAY_TOKEN"
    },
    "controlUi": {
      "allowInsecureAuth": true
    }
  },
  "channels": {
    "telegram": {
      "enabled": $TELEGRAM_ENABLED,
      "botToken": "${TELEGRAM_BOT_TOKEN:-}",
      "dmPolicy": "$TELEGRAM_DM_POLICY",
      "allowFrom": $TELEGRAM_ALLOW_FROM,
      "groupPolicy": "allowlist",
      "streamMode": "partial"
    }
  },
  "plugins": {
    "entries": {
      "telegram": {
        "enabled": $TELEGRAM_ENABLED
      }
    }
  },
  "messages": {
    "ackReactionScope": "group-mentions"
  },
  "commands": {
    "native": "auto",
    "nativeSkills": "auto"
  }$(if [ "$OLLAMA_ENABLED" = "true" ]; then echo ',
  "models": {
    "providers": {
      "ollama": {
        "baseUrl": "'"$OLLAMA_BASE_URL"'"
      }
    },
    "aliases": {
      "kimi": "ollama/kimi-k2.5:cloud",
      "qwen": "ollama/qwen3-coder-next"
    }
  }'; fi)
}
EOF

    echo "Config generated at $CONFIG_FILE"
    echo ""
    echo "=== CONFIG CONTENT ==="
    cat "$CONFIG_FILE"
    echo ""
    echo "=== END CONFIG ==="
    
    # Show token if it was auto-generated
    if [ "$TOKEN_GENERATED" = "1" ]; then
        echo ""
        echo "============================================"
        echo "AUTO-GENERATED GATEWAY TOKEN (save this!):"
        echo "$GATEWAY_TOKEN"
        echo "============================================"
        echo ""
    fi
fi

# If a custom config is mounted, use it
if [ -f "/config/openclaw.json" ]; then
    echo "Using mounted config from /config/openclaw.json"
    cp /config/openclaw.json "$CONFIG_FILE"
fi

# Always show config content for debugging
echo ""
echo "=== CURRENT CONFIG ==="
# Uncomment below for debug purposes
# cat "$CONFIG_FILE"
echo ""
echo "=== END CONFIG ==="
echo ""

# Show startup info
echo ""
echo "╔═══════════════════════════════════════════╗"
echo "║         openclaw Docker Container         ║"
echo "╚═══════════════════════════════════════════╝"
echo ""
echo "  Port:      ${openclaw_GATEWAY_PORT:-4001}"
echo "  Workspace: $WORKSPACE"
echo "  Config:    $CONFIG_FILE"
echo "  Telegram:  $TELEGRAM_ENABLED"
echo "  Ollama:    $OLLAMA_ENABLED"
echo "  GitHub:    $GITHUB_ENABLED"
echo ""

# Execute the command
exec "$@"
