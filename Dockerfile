# Tracks the Node 22 LTS line: patch and Debian security updates, never a major bump
FROM node:22-bookworm-slim

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
RUN mkdir -p /workspace /home/node/.claude /etc/claude-code \
    && chown -R node:node /workspace /home/node/.claude \
    && chmod 777 /home/node

# Switch to non-root user — required for --dangerously-skip-permissions
USER node

# Set global directory for installs
ENV NPM_CONFIG_PREFIX=/usr/local/share/npm-global

# Make claude binary findable after install
ENV PATH=$PATH:/usr/local/share/npm-global/bin

# Disable Claude Code's auto-updater: whatever version this image is built with is
# the version it keeps for its whole life. Moving forward is a deliberate rebuild.
ENV DISABLE_AUTOUPDATER=1

# Install Claude Code globally from the `stable` channel, so a rebuild picks up the
# current stable release. This RUN line never changes, so Docker will happily reuse
# a cached layer and install nothing new — rebuild with --no-cache to actually move.
# Note: never use sudo npm install -g — it causes permission issues
RUN npm install -g @anthropic-ai/claude-code@stable \
    && claude --version

WORKDIR /workspace

# Copy container-level guidance for the model.
# Goes to the managed-policy path (/etc/claude-code/CLAUDE.md), NOT ~/.claude/CLAUDE.md:
# the launcher bind-mounts the project .claude over /home/node/.claude, which would
# shadow a user-level file. The managed-policy path is outside $HOME, loads every
# session, and can't be excluded — so it survives the mount on both Docker and Singularity.
# Note: the anthropic path in claude-in-a-box shadows this file with
# /dev/null, since the guidance is open-source-specific and wrong for a frontier model.
COPY assets/CLAUDE.md /etc/claude-code/CLAUDE.md

ENTRYPOINT ["claude"]
