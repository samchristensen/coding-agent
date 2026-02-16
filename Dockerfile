# =============================================================================
# Cody — Agentic coding Docker image
# =============================================================================
#
# Run against a repo with a task:
#   docker run --rm \
#     -v /var/run/docker.sock:/var/run/docker.sock \
#     -e REPO="owner/repo" \
#     -e TASK="Fix the failing tests and open a PR" \
#     -e BRANCH="feature-branch" \
#     -e ANTHROPIC_API_KEY \
#     -e OPENAI_API_KEY \
#     -e GH_TOKEN="$(gh auth token)" \
#     ghcr.io/samchristensen/cody:latest
#
#
# Interactive shell:
#   docker run -it --rm \
#     -v /var/run/docker.sock:/var/run/docker.sock \
#     -v $(pwd):/workspace \
#     -e ANTHROPIC_API_KEY -e OPENAI_API_KEY -e GH_TOKEN \
#     ghcr.io/samchristensen/cody:latest
#
# =============================================================================

FROM ubuntu:24.04

LABEL org.opencontainers.image.source="https://github.com/samchristensen/coding-agent"
LABEL org.opencontainers.image.description="Cody — agentic coding image with OpenCode, gh, Docker, and utilities"

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
# 2. just — command runner
# ---------------------------------------------------------------------------
ARG JUST_VERSION=1.40.0
RUN curl -fsSL "https://github.com/casey/just/releases/download/${JUST_VERSION}/just-${JUST_VERSION}-x86_64-unknown-linux-musl.tar.gz" \
    | tar xz -C /usr/local/bin just

# ---------------------------------------------------------------------------
# 3. yq — YAML processor (static binary)
# ---------------------------------------------------------------------------
ARG YQ_VERSION=v4.52.4
RUN curl -fsSL "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_amd64" \
    -o /usr/local/bin/yq \
    && chmod +x /usr/local/bin/yq

# ---------------------------------------------------------------------------
# 4. git-delta — better diffs with syntax highlighting
# ---------------------------------------------------------------------------
ARG DELTA_VERSION=0.18.2
RUN curl -fsSL "https://github.com/dandavison/delta/releases/download/${DELTA_VERSION}/git-delta_${DELTA_VERSION}_amd64.deb" \
    -o /tmp/delta.deb \
    && dpkg -i /tmp/delta.deb \
    && rm /tmp/delta.deb

# ---------------------------------------------------------------------------
# 5. GitHub CLI (gh)
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
# 6. Docker CLI + Docker Compose plugin
#    (uses the host Docker daemon via mounted /var/run/docker.sock)
# ---------------------------------------------------------------------------
RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
       -o /etc/apt/keyrings/docker.asc \
    && chmod a+r /etc/apt/keyrings/docker.asc \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
       > /etc/apt/sources.list.d/docker.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
       docker-ce-cli \
       docker-compose-plugin \
    && rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------------------------
# 7. Node.js 22.x (required by OpenCode)
# ---------------------------------------------------------------------------
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------------------------
# 8. OpenCode — the AI coding agent
# ---------------------------------------------------------------------------
RUN npm install -g opencode-ai@latest

# ---------------------------------------------------------------------------
# 9. Git defaults for the container
# ---------------------------------------------------------------------------
RUN git config --global user.name "Cody" \
    && git config --global user.email "cody@agent" \
    && git config --global init.defaultBranch main

# ---------------------------------------------------------------------------
# 10. OpenCode global config (minimal defaults)
#
#    Model selection is left to the repo-local opencode.json.
#    Only non-model defaults (permission, autoupdate) are set here.
# ---------------------------------------------------------------------------
RUN mkdir -p /root/.config/opencode \
    && cat <<'EOF' > /root/.config/opencode/opencode.json
{
  "$schema": "https://opencode.ai/config.json",
  "permission": "allow",
  "autoupdate": false
}
EOF

# ---------------------------------------------------------------------------
# 11. Entrypoint script
# ---------------------------------------------------------------------------
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# ---------------------------------------------------------------------------
# 12. Workspace — default mount point for repos
# ---------------------------------------------------------------------------
WORKDIR /workspace

ENTRYPOINT ["entrypoint.sh"]
CMD []
