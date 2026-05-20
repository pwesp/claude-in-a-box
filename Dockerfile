FROM node:22.22.2-bookworm-slim

# Install tools (and clean up)
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    nano \
    htop \
    python3 \
    python3-pip \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Give the pre-existing node user access to global npm directory for installs
RUN mkdir -p /usr/local/share/npm-global \
    && chown -R node:node /usr/local/share

# Create directories Claude Code needs
# chmod 777 on /home/node allows arbitrary host UIDs (e.g. uid≠1000) to write here
RUN mkdir -p /workspace /home/node/.claude \
    && chown -R node:node /workspace /home/node/.claude \
    && chmod 777 /home/node

# Switch to non-root user — required for --dangerously-skip-permissions
USER node

# Set global directory for installs
ENV NPM_CONFIG_PREFIX=/usr/local/share/npm-global

# Make claude binary findable after install
ENV PATH=$PATH:/usr/local/share/npm-global/bin

# Disable Claude Code's auto-updater so the pinned install stays stable
ENV DISABLE_AUTOUPDATER=1

# Install Claude Code globally
# Note: never use sudo npm install -g — it causes permission issues
RUN npm install -g @anthropic-ai/claude-code

WORKDIR /workspace

# Copy container-level guidance for the model
COPY assets/CLAUDE.md /home/node/.claude/CLAUDE.md

ENTRYPOINT ["claude"]
