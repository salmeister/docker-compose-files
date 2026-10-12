#!/bin/sh
set -eu

echo "=== OpenClaw Gateway Startup ==="

BREW_PREFIX="/home/linuxbrew/.linuxbrew"
BREW_BIN="$BREW_PREFIX/bin/brew"
NODE24_BIN="$BREW_PREFIX/opt/node@24/bin"

log() { echo "$*"; }
warn() { echo "WARNING: $*" >&2; }

# ---------- Homebrew ----------
if [ ! -x "$BREW_BIN" ]; then
  log "Installing Homebrew..."
  NONINTERACTIVE=1 curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh | bash
fi

eval "$("$BREW_BIN" shellenv)"
export PATH="$BREW_PREFIX/bin:$BREW_PREFIX/sbin:$PATH"
log "Brew ready: $(brew --version)"

# Core runtime deps (fatal if these fail)
brew install node@24 simdjson
# ---------- Node setup ----------
# Node 24 MUST be first in PATH — avoid Cellar Node 25 shim if present
export PATH="$NODE24_BIN:$BREW_PREFIX/bin:$BREW_PREFIX/sbin:$PATH"
hash -r 2>/dev/null || true
export LD_LIBRARY_PATH="$BREW_PREFIX/lib:${LD_LIBRARY_PATH:-}"

if ! ls "$BREW_PREFIX/lib/libsimdjson.so"* >/dev/null 2>&1; then
  echo "ERROR: simdjson library not found under $BREW_PREFIX/lib"
  exit 1
fi

npm config set prefix "$BREW_PREFIX"
export NODE_PATH="$BREW_PREFIX/lib/node_modules"
npm install -g "npm@^11"
NODE_MAJOR="$(node -p 'process.versions.node.split(".")[0]')"
if [ "$NODE_MAJOR" != "24" ]; then
  echo "ERROR: Expected Node 24.x but found $(node -v)"
  exit 1
fi

log "Using node: $(node -v) (exec: $(command -v node))"
log "Using npm: $(npm -v) (exec: $(command -v npm))"
log "npm prefix: $(npm config get prefix)"
log "LD_LIBRARY_PATH: $LD_LIBRARY_PATH"

# ---------- Python ----------
if [ ! -L "$BREW_PREFIX/bin/python" ]; then
  ln -sf python3 "$BREW_PREFIX/bin/python"
fi
log "Python: $(python --version)"

# ---------- Python packages for agents (persistent) ----------
if ! python3 -c "import bs4" 2>/dev/null; then
  log "Installing beautifulsoup4 for web scraping..."
  pip3 install --user --break-system-packages beautifulsoup4 lxml --quiet
  log "beautifulsoup4 installed: $(pip3 show beautifulsoup4 2>/dev/null | grep Version)"
else
  log "beautifulsoup4 ready: $(pip3 show beautifulsoup4 2>/dev/null | grep Version)"
fi

# ---------- .NET SDK (for building and running dotnet APIs) ----------
# Install wget (needed for dotnet-install.sh to download the SDK)
if ! command -v wget >/dev/null 2>&1; then
  log "Installing wget..."
  brew install wget 2>&1 | tail -3
fi

# Install .NET SDK 10.0.302
if ! command -v dotnet >/dev/null 2>&1; then
  log "Installing .NET SDK 10.0.302..."
  python3 -c "import urllib.request; urllib.request.urlretrieve('https://dot.net/v1/dotnet-install.sh', '/tmp/dotnet-install.sh')"
  chmod +x /tmp/dotnet-install.sh
  /tmp/dotnet-install.sh --version 10.0.302 --install-dir "$BREW_PREFIX" 2>&1 | tail -3
  rm -f /tmp/dotnet-install.sh
fi

# Ensure dotnet is in PATH
export PATH="$BREW_PREFIX:$PATH"

# Add ICU libraries to LD_LIBRARY_PATH (dotnet requires libicu)
export LD_LIBRARY_PATH="$BREW_PREFIX/opt/icu4c@78/lib:$LD_LIBRARY_PATH"

log "dotnet ready: $(dotnet --version)"

#--------- QMD memory backend ----------
QMD_BIN="/home/node/.openclaw/bin/qmd"
QMD_DIST="/home/node/.openclaw/bin/qmd-dist"
mkdir -p /home/node/.openclaw/bin
if [ ! -x "$QMD_BIN" ] || [ ! -d "$QMD_DIST" ]; then
  log "QMD not found in persistent volume — installing from scratch..."
  if [ ! -x "/home/node/.bun/bin/bun" ]; then
    curl -fsSL https://bun.sh/install | bash || warn "bun install failed; continuing"
  fi
  export PATH="/home/node/.bun/bin:$PATH"
  if command -v bun >/dev/null 2>&1; then
    bun install -g "https://github.com/tobi/qmd" || warn "QMD global install failed"
    QMD_PKG="/home/node/.bun/install/global/node_modules/@tobilu/qmd"
    if [ -d "$QMD_PKG" ]; then
      (cd "$QMD_PKG" && bun add -d @types/node >/dev/null 2>&1 || true && bun run build >/dev/null 2>&1 || true)
      mkdir -p "$QMD_DIST"
      cp -r "$QMD_PKG/dist/"* "$QMD_DIST/" 2>/dev/null || true
      cp -r "$QMD_PKG/node_modules" "$QMD_DIST/node_modules" 2>/dev/null || true
      echo '{"type":"module"}' > "$QMD_DIST/package.json"
      printf '#!/bin/sh\nexec node /home/node/.openclaw/bin/qmd-dist/qmd.js "$@"\n' > "$QMD_BIN"
      chmod +x "$QMD_BIN"
      log "QMD installed to persistent volume: $QMD_BIN"
    else
      warn "QMD package path missing after install"
    fi
  else
    warn "bun unavailable; skipping QMD bootstrap"
  fi
else
  log "QMD found at $QMD_BIN (persistent — skipping install)"
fi

# ---------- yt-dlp via pip (apt broken due to GLIBC mismatch in Homebrew Python) ----------
export PATH="/home/node/.local/bin:$PATH"
if ! command -v yt-dlp >/dev/null 2>&1; then
  log "Installing yt-dlp via pip..."
  pip3 install --user --break-system-packages yt-dlp --quiet || warn "yt-dlp install failed; skipping"
  log "yt-dlp ready: $(yt-dlp --version 2>/dev/null)" || true
fi

# ---------- Chromium system deps + Playwright ----------
# libnspr4 is required by Playwright's bundled Chromium but not always present on Debian
if ! find /home/node/.cache/ms-playwright -maxdepth 2 -type d -name 'chromium-*' >/dev/null 2>&1; then
  if [ -f /app/node_modules/playwright-core/cli.js ]; then
    log "Installing Chromium system dependencies..."
    apt-get install -y -qq libnspr4 libnss3 libatk1 libatk-bridge2 libdrm2 libxkbcommon0 libgbm1 || warn "Chromium system deps install failed"
    log "Installing Playwright Chromium..."
    node /app/node_modules/playwright-core/cli.js install chromium || warn "Playwright Chromium install failed"
    log "Playwright Chromium installed!"
  else
    warn "playwright-core cli not found; skipping chromium install"
  fi
fi

# ---------- Optional npm CLIs (non-fatal) ----------
if ! command -v gws >/dev/null 2>&1; then
  log "Installing gws (Google Workspace CLI)..."
  npm install -g @googleworkspace/cli@latest || warn "gws install failed"
fi

if ! command -v summarize >/dev/null 2>&1; then
  log "Installing summarize..."
  npm install -g @steipete/summarize@latest || warn "summarize install failed"
fi
if ! command -v bw >/dev/null 2>&1; then
  log "Installing Bitwarden CLI..."
  npm install -g @bitwarden/cli || warn "bw install failed"
  [ -x "$(command -v bw)" ] && log "bw version: $(bw --version)" || true
fi


# ---------- xurl (X/Twitter API CLI) ----------
if ! command -v xurl >/dev/null 2>&1; then
  log "Installing xurl for X API access..."
  npm install -g @xdevplatform/xurl || warn "xurl install failed"
fi
# Restore xurl bearer token from Vaultwarden
if command -v xurl >/dev/null 2>&1 && ! xurl auth status 2>/dev/null | grep -q 'bearer: ✓'; then
  log "Restoring xurl bearer token from Vaultwarden..."
  BW_SESSION_FILE="/home/node/.openclaw/.bw-session"
  if [ -f "$BW_SESSION_FILE" ]; then
    export BW_SESSION=$(cat "$BW_SESSION_FILE")
    # vault-get.sh may exit non-zero if token isn't found — || true prevents set -e from killing the script
    XURL_TOKEN="$(/home/node/.openclaw/workspace/scripts/vault-get.sh x-api-bearer password 2>/dev/null)" || XURL_TOKEN=""
    if [ -n "$XURL_TOKEN" ]; then
      xurl auth app --bearer-token "$XURL_TOKEN" && log "xurl bearer token restored."
    else
      warn "Could not retrieve x-api-bearer from Vaultwarden — xurl unauthenticated"
    fi
  else
    warn "No Bitwarden session found — xurl bearer token not restored"
  fi
fi

# ============================================================
# Pre-launch Chromium for browser tool
# ============================================================
CHROME_BIN=$(find /home/node/.cache/ms-playwright -name 'chrome' -path '*/chrome-linux64/chrome' 2>/dev/null | head -1)
CHROME_UDP="/home/node/.openclaw/browser/openclaw/user-data"
CHROME_CDP_PORT="${OPENCLAW_CDP_PORT:-18800}"

if [ -x "$CHROME_BIN" ]; then
  log "Pre-launching Chromium on CDP port $CHROME_CDP_PORT..."
  mkdir -p "$CHROME_UDP"
  export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp/xdg-runtime-chrome}"
  mkdir -p "$XDG_RUNTIME_DIR"
  chmod 700 "$XDG_RUNTIME_DIR"
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
  log "Chromium launched (pid=$CHROME_PID), waiting for CDP..."
  CHROME_READY=0
  for i in $(seq 1 30); do
    if curl -sf "http://127.0.0.1:$CHROME_CDP_PORT/json/version" > /dev/null 2>&1; then
      CHROME_READY=1
      log "Chromium CDP ready after ${i}s"
      break
    fi
    sleep 1
  done
  if [ "$CHROME_READY" -eq 0 ]; then
    warn "Chromium CDP did not respond within 30s — browser tool may time out on first use"
  fi
else
  warn "Playwright Chromium not found at $CHROME_BIN"
  warn "Run: node /app/node_modules/playwright-core/cli.js install chromium"
fi
# ============================================================

# ---------- Start gateway ----------
#echo "OpenClaw binary: $(command -v openclaw)"
#echo "OpenClaw version: $(openclaw --version 2>&1)"
#log "Starting OpenClaw gateway..."
#exec openclaw gateway --bind loopback
# ---------- Start gateway ----------
OPENCLAW_BIN="/app/openclaw.mjs"
echo "OpenClaw binary: $OPENCLAW_BIN"
echo "OpenClaw version: $("$OPENCLAW_BIN" --version 2>&1)"
log "Starting OpenClaw gateway..."
exec "$OPENCLAW_BIN" gateway --bind loopback --port 18789
