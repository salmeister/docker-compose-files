#!/bin/sh
set -e

echo "=== OpenClaw Gateway Startup ==="

# Install Homebrew if needed
if [ ! -x /home/linuxbrew/.linuxbrew/bin/brew ]; then
  echo 'Installing Homebrew...';
  NONINTERACTIVE=1 curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh | bash;
fi

# Set up Homebrew environment
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
export PATH="/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:$PATH"
echo "Brew ready: $(brew --version)"

# Install Chromium if needed (browser control)
# NOTE: The apt chromium package is a snap stub that doesn't work in Docker.
# We use Playwright's bundled Chromium instead (see below). This block is intentionally
# left in place but effectively a no-op since 'chromium' will be found as a stub.
if ! command -v chromium &> /dev/null; then
  echo 'Installing Chromium apt package (stub — Playwright binary used for actual automation)...';
  apt-get update -qq && apt-get install -y -qq chromium chromium-driver;
  echo 'Chromium apt package installed!'
fi

# Install Playwright Chromium if needed (real headless browser for automation)
if [ ! -d "/home/node/.cache/ms-playwright/chromium-"* ] 2>/dev/null; then
  echo 'Installing Playwright Chromium...'
  node /app/node_modules/playwright-core/cli.js install chromium
  echo 'Playwright Chromium installed!'
fi

# Install yt-dlp if needed (YouTube transcript extraction)
if ! command -v yt-dlp &> /dev/null; then
  echo 'Installing yt-dlp for YouTube research...';
  apt-get install -y -qq yt-dlp;
  echo 'yt-dlp installed!'
fi

# Install Bitwarden CLI if needed (secure credential management)
if ! command -v bw &> /dev/null; then
  echo 'Installing Bitwarden CLI for Vaultwarden integration...';
  npm install -g @bitwarden/cli;
  echo 'Bitwarden CLI installed!';
  echo "Version: $(bw --version)";
fi

# Install xurl if needed (X/Twitter API CLI)
if ! command -v xurl &> /dev/null; then
  echo 'Installing xurl for X API access...';
  npm install -g @xdevplatform/xurl;
  echo "xurl installed: $(xurl version)";
fi

# ============================================================
# Pre-launch Chromium for browser tool
# ============================================================
# OpenClaw's browser/start route has a hard 15s timeout. On cold start, Chrome's
# bootstrap-decorate sequence takes longer than that, causing every browser action
# to fail with "timed out after 15000ms".
#
# Fix: launch Chrome here (before the gateway) so it's CDP-ready when first used.
# The gateway's ensureBrowserAvailable() will see it already running and skip the spawn.
#
# Profile config mirrors openclaw.json browser section:
#   executablePath, noSandbox, headless, defaultProfile=openclaw, cdpPort=18800
CHROME_BIN="/home/node/.cache/ms-playwright/chromium-1208/chrome-linux64/chrome"
CHROME_UDP="/home/node/.openclaw/browser/openclaw/user-data"
CHROME_CDP_PORT=18800

if [ -x "$CHROME_BIN" ]; then
  echo "Pre-launching Chromium on CDP port $CHROME_CDP_PORT..."
  mkdir -p "$CHROME_UDP"
  # Remove stale singleton locks from previous unclean shutdowns
  rm -f "$CHROME_UDP/SingletonLock" "$CHROME_UDP/SingletonCookie" "$CHROME_UDP/SingletonSocket"
  "$CHROME_BIN" \
    --remote-debugging-port=$CHROME_CDP_PORT \
    --remote-debugging-address=127.0.0.1 \
    --user-data-dir="$CHROME_UDP" \
    --no-first-run \
    --no-default-browser-check \
    --disable-sync \
    --disable-background-networking \
    --disable-component-update \
    --disable-features=Translate,MediaRouter \
    --disable-session-crashed-bubble \
    --hide-crash-restore-bubble \
    --password-store=basic \
    --headless=new \
    --disable-gpu \
    --no-sandbox \
    --disable-setuid-sandbox \
    --disable-dev-shm-usage \
    about:blank &
  CHROME_PID=$!
  echo "Chromium launched (pid=$CHROME_PID), waiting for CDP..."
  # Poll until CDP responds (max 30 seconds)
  CHROME_READY=0
  for i in $(seq 1 30); do
    if curl -sf "http://127.0.0.1:$CHROME_CDP_PORT/json/version" > /dev/null 2>&1; then
      CHROME_READY=1
      echo "Chromium CDP ready after ${i}s"
      break
    fi
    sleep 1
  done
  if [ "$CHROME_READY" -eq 0 ]; then
    echo "WARNING: Chromium CDP did not respond within 30s — browser tool may time out on first use"
  fi
else
  echo "WARNING: Playwright Chromium not found at $CHROME_BIN"
  echo "         Run: node /app/node_modules/playwright-core/cli.js install chromium"
  echo "         Browser tool will attempt to launch Chrome itself (may time out on first call)"
fi
# ============================================================

# Start gateway
echo "Starting OpenClaw gateway..."
exec node dist/index.js gateway --bind loopback
