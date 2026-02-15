# =============================================================================
# Cody — Agentic coding Docker image
# =============================================================================
# Usage:
#   docker run -it --rm \
#     -v $(pwd):/workspace \
#     -e ANTHROPIC_API_KEY \
#     -e OPENAI_API_KEY \
#     -e GH_TOKEN="$(gh auth token)" \
#     ghcr.io/samchristensen/cody:latest
# =============================================================================

FROM ubuntu:24.04

LABEL org.opencontainers.image.source="https://github.com/samchristensen/coding-agent"
LABEL org.opencontainers.image.description="Cody — agentic coding image with OpenCode, gh, and utilities"

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# ---------------------------------------------------------------------------
# 1. Core system packages
# ---------------------------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    gnupg \
    less \
    tree \
    unzip \
    vim \
    wget \
    # --- context-limiting / search utilities ---
    jq \
    ripgrep \
    fd-find \
    fzf \
    bat \
    && rm -rf /var/lib/apt/lists/*

# Symlink fd-find and bat to their canonical names
RUN ln -sf /usr/bin/fdfind /usr/local/bin/fd \
    && ln -sf /usr/bin/batcat /usr/local/bin/bat

# ---------------------------------------------------------------------------
# 2. yq — YAML processor (static binary)
# ---------------------------------------------------------------------------
ARG YQ_VERSION=v4.52.4
RUN curl -fsSL "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_amd64" \
    -o /usr/local/bin/yq \
    && chmod +x /usr/local/bin/yq

# ---------------------------------------------------------------------------
# 3. git-delta — better diffs with syntax highlighting
# ---------------------------------------------------------------------------
ARG DELTA_VERSION=0.18.2
RUN curl -fsSL "https://github.com/dandavison/delta/releases/download/${DELTA_VERSION}/git-delta_${DELTA_VERSION}_amd64.deb" \
    -o /tmp/delta.deb \
    && dpkg -i /tmp/delta.deb \
    && rm /tmp/delta.deb

# ---------------------------------------------------------------------------
# 4. GitHub CLI (gh)
# ---------------------------------------------------------------------------
RUN mkdir -p -m 755 /etc/apt/keyrings \
    && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
       -o /etc/apt/keyrings/githubcli-archive-keyring.gpg \
    && chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
       > /etc/apt/sources.list.d/github-cli.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends gh \
    && rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------------------------
# 5. Node.js 22.x (required by OpenCode)
# ---------------------------------------------------------------------------
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------------------------
# 6. OpenCode — the AI coding agent
# ---------------------------------------------------------------------------
RUN npm install -g opencode-ai@latest

# ---------------------------------------------------------------------------
# 7. Git defaults for the container
# ---------------------------------------------------------------------------
RUN git config --global user.name "Cody" \
    && git config --global user.email "cody@agent" \
    && git config --global init.defaultBranch main

# ---------------------------------------------------------------------------
# 8. OpenCode global config
#    - model:      anthropic/claude-sonnet-4-6
#    - permission: allow (auto-approve all tools — no interactive prompts)
#    - autoupdate: false (pinned version in image, no surprise updates)
# ---------------------------------------------------------------------------
RUN mkdir -p /root/.config/opencode \
    && cat <<'EOF' > /root/.config/opencode/opencode.json
{
  "$schema": "https://opencode.ai/config.json",
  "model": "anthropic/claude-sonnet-4-6",
  "permission": "allow",
  "autoupdate": false
}
EOF

# ---------------------------------------------------------------------------
# 9. Workspace — default mount point for repos
# ---------------------------------------------------------------------------
WORKDIR /workspace

# ---------------------------------------------------------------------------
# Default entrypoint: drop into bash so you can run opencode, gh, etc.
# ---------------------------------------------------------------------------
CMD ["bash"]
