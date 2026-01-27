#!/bin/bash
set -e

CONFIG_DIR="/root/.clawdbot"
CONFIG_FILE="$CONFIG_DIR/clawdbot.json"
WORKSPACE="/root/clawd"

# Ensure directories exist
mkdir -p "$CONFIG_DIR" "$WORKSPACE/memory"

# Determine if Telegram is enabled
if [ -n "$TELEGRAM_BOT_TOKEN" ]; then
    TELEGRAM_ENABLED="true"
else
    TELEGRAM_ENABLED="false"
fi

# Generate config if it doesn't exist or if env vars are set
if [ ! -f "$CONFIG_FILE" ] || [ -n "$CLAWDBOT_REGENERATE_CONFIG" ]; then
    echo "Generating Moltbot configuration..."
    
    # Use provided token or generate one
    if [ -z "$CLAWDBOT_GATEWAY_TOKEN" ]; then
        GATEWAY_TOKEN=$(openssl rand -hex 32)
        TOKEN_GENERATED=1
    else
        GATEWAY_TOKEN="$CLAWDBOT_GATEWAY_TOKEN"
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
    "port": ${CLAWDBOT_GATEWAY_PORT:-4001},
    "mode": "local",
    "bind": "lan",
    "auth": {
      "mode": "token",
      "token": "$GATEWAY_TOKEN"
    }
  },
  "channels": {
    "telegram": {
      "enabled": $TELEGRAM_ENABLED,
      "botToken": "${TELEGRAM_BOT_TOKEN:-}",
      "dmPolicy": "pairing",
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
  }
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
if [ -f "/config/clawdbot.json" ]; then
    echo "Using mounted config from /config/clawdbot.json"
    cp /config/clawdbot.json "$CONFIG_FILE"
fi

# Always show config content for debugging
echo ""
echo "=== CURRENT CONFIG ==="
cat "$CONFIG_FILE"
echo ""
echo "=== END CONFIG ==="
echo ""

# Show startup info
echo ""
echo "╔═══════════════════════════════════════════╗"
echo "║         Moltbot Docker Container         ║"
echo "╚═══════════════════════════════════════════╝"
echo ""
echo "  Port:      ${CLAWDBOT_GATEWAY_PORT:-4001}"
echo "  Workspace: $WORKSPACE"
echo "  Config:    $CONFIG_FILE"
echo "  Telegram:  $TELEGRAM_ENABLED"
echo ""

# Execute the command
exec "$@"
