#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Cody entrypoint — clone a repo, optionally run a task, or drop into a shell
# =============================================================================
#
# Environment variables:
#   REPO                   - GitHub repo to clone (URL or owner/repo shorthand)
#   TASK                   - Prompt to run via `opencode run` (optional)
#   BRANCH                 - Branch to checkout after cloning (optional)
#   GH_TOKEN               - GitHub token for auth (cloning private repos + gh CLI)
#   ANTHROPIC_API_KEY      - Anthropic API key (used by OpenCode)
#   OPENAI_API_KEY         - OpenAI API key (used by OpenCode)
#   OPENCODE_CONFIG_CONTENT - Inline JSON to override OpenCode config (optional)
#
# If REPO is set, clones into /workspace/<repo-name>.
# If TASK is set, runs `opencode run "<task>"` in the repo directory.
# If neither is set, drops into an interactive bash shell.
# =============================================================================

WORKSPACE="/workspace"

# ---------------------------------------------------------------------------
# Configure gh CLI auth via GH_TOKEN if available
# ---------------------------------------------------------------------------
if [[ -n "${GH_TOKEN:-}" ]]; then
  export GH_TOKEN
  # Also configure git to use the token for HTTPS cloning
  git config --global url."https://x-access-token:${GH_TOKEN}@github.com/".insteadOf "https://github.com/"
fi

# ---------------------------------------------------------------------------
# Clone the repo if REPO is specified
# ---------------------------------------------------------------------------
if [[ -n "${REPO:-}" ]]; then
  # Normalize: if it's just owner/repo, expand to full URL
  if [[ "$REPO" != http* && "$REPO" != git@* ]]; then
    REPO="https://github.com/${REPO}.git"
  fi

  # Extract repo name from URL for the directory name
  REPO_NAME=$(basename "$REPO" .git)
  CLONE_DIR="${WORKSPACE}/${REPO_NAME}"

  if [[ -d "$CLONE_DIR" ]]; then
    echo "[cody] Repo directory ${CLONE_DIR} already exists, pulling latest..."
    cd "$CLONE_DIR"
    git pull --ff-only || true
  else
    echo "[cody] Cloning ${REPO} into ${CLONE_DIR}..."
    git clone "$REPO" "$CLONE_DIR"
    cd "$CLONE_DIR"
  fi

  # Checkout a specific branch if requested
  if [[ -n "${BRANCH:-}" ]]; then
    echo "[cody] Checking out branch: ${BRANCH}"
    git checkout "$BRANCH" 2>/dev/null || git checkout -b "$BRANCH" "origin/${BRANCH}"
  fi
else
  cd "$WORKSPACE"
fi

# ---------------------------------------------------------------------------
# Run the task or drop into interactive mode
# ---------------------------------------------------------------------------
if [[ -n "${TASK:-}" ]]; then
  echo "[cody] Running task: ${TASK}"
  exec opencode run "$TASK"
elif [[ $# -gt 0 ]]; then
  # If args were passed to the container (e.g. docker run ... cody opencode run "...")
  exec "$@"
else
  echo "[cody] No TASK specified. Dropping into interactive shell."
  echo "[cody] Tools available: opencode, gh, jq, yq, rg, fd, fzf, bat, delta, docker, docker compose"
  exec bash
fi
