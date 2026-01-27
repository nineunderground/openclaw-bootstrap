FROM ubuntu:24.04

LABEL maintainer="nineunderground"
LABEL description="Moltbot Gateway in Docker"

# Prevent interactive prompts during install
ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl \
    ca-certificates \
    gnupg \
    git \
    jq \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js 22
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# Install Moltbot globally
RUN npm install -g moltbot@latest

# Create directories
RUN mkdir -p /root/.clawdbot /root/clawd/memory

# Set workspace
WORKDIR /root/clawd

# Default port (can be overridden)
ENV CLAWDBOT_GATEWAY_PORT=4001

# Copy entrypoint script
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Expose gateway port
EXPOSE 4001

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:${CLAWDBOT_GATEWAY_PORT}/health || exit 1

# Run entrypoint
ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["moltbot", "gateway"]
