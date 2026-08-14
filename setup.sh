#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

# ============================================================
# PlayitTermux
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RESET='\033[0m'

info()    { echo -e "${CYAN}[INFO]${RESET} $*"; }
success() { echo -e "${GREEN}[OK]${RESET} $*"; }
error()   { echo -e "${RED}[ERROR]${RESET} $*" >&2; }

# ============================================================
# Termux check
# ============================================================

if [ ! -d "/data/data/com.termux" ]; then
    error "Run this script inside Termux."
    exit 1
fi

if [ "$(id -u)" -eq 0 ]; then
    error "Do not run this script as root in Termux."
    exit 1
fi

# ============================================================
# Termux dependencies
# ============================================================

info "Installing Termux dependencies..."

pkg update -y
pkg install -y proot-distro

success "Termux dependencies ready."

# ============================================================
# Debian PRoot
# ============================================================

if proot-distro login debian -- true >/dev/null 2>&1; then
    success "Debian PRoot already exists."
else
    info "Installing Debian PRoot..."
    proot-distro install debian
    success "Debian PRoot installed."
fi

# ============================================================
# Install inside PRoot
# ============================================================

info "Installing Playit inside Debian PRoot..."

proot-distro login debian -- bash -s <<'PROOT'
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RESET='\033[0m'

info()    { echo -e "${CYAN}[INFO]${RESET} $*"; }
success() { echo -e "${GREEN}[OK]${RESET} $*"; }
error()   { echo -e "${RED}[ERROR]${RESET} $*" >&2; }

# ============================================================
# Configuration
# ============================================================

PLAYIT_DIR="$HOME/PlayitTermux"
PLAYIT_BIN="$PLAYIT_DIR/bin"
BASE_URL="https://github.com/playit-cloud/playit-agent/releases/latest/download"

# ============================================================
# Checks
# ============================================================

if [ "$(id -u)" -ne 0 ]; then
    error "Setup must run as root inside PRoot."
    exit 1
fi

# ============================================================
# Detect architecture
# ============================================================

case "$(uname -m)" in
    aarch64|arm64)
        PLAYIT_ARCH="aarch64"
        ;;

    x86_64|amd64)
        PLAYIT_ARCH="amd64"
        ;;

    armv7l|armv7)
        PLAYIT_ARCH="armv7"
        ;;

    i686|i386)
        PLAYIT_ARCH="i686"
        ;;

    *)
        error "Unsupported architecture: $(uname -m)"
        error "Supported: aarch64, amd64, armv7, i686"
        exit 1
        ;;
esac

DAEMON_URL="$BASE_URL/playit-linux-$PLAYIT_ARCH"
CLI_URL="$BASE_URL/playit-cli-linux-$PLAYIT_ARCH"

success "Architecture: $(uname -m) -> $PLAYIT_ARCH"

# ============================================================
# Debian dependencies
# ============================================================

info "Installing Debian dependencies..."

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y curl ca-certificates procps

mkdir -p "$PLAYIT_BIN"

# ============================================================
# Stop existing daemon
# ============================================================

if pgrep -x playitd >/dev/null 2>&1; then
    info "Stopping running Playit..."

    pkill -x playitd || true
    sleep 1

    success "Playit stopped."
fi

# ============================================================
# Download helper
# ============================================================

download() {
    local url="$1"
    local output="$2"
    local name="$3"
    local tmp="${output}.tmp"

    rm -f "$tmp"

    info "Installing $name..."

    curl \
        -fL \
        --progress-bar \
        --connect-timeout 20 \
        --max-time 300 \
        --retry 3 \
        --retry-delay 2 \
        -o "$tmp" \
        "$url"

    if [ ! -s "$tmp" ]; then
        rm -f "$tmp"
        error "$name download failed."
        exit 1
    fi

    chmod +x "$tmp"
    mv "$tmp" "$output"

    success "$name installed."
}

# ============================================================
# Playit binaries
# ============================================================

download \
    "$DAEMON_URL" \
    "$PLAYIT_BIN/playitd" \
    "Playit daemon"

download \
    "$CLI_URL" \
    "$PLAYIT_BIN/playit-cli" \
    "Playit CLI"

# ============================================================
# Start
# ============================================================

cat > "$PLAYIT_BIN/start-playit" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

PLAYIT_DIR="$HOME/PlayitTermux"
PLAYIT_BIN="$PLAYIT_DIR/bin"

PLAYITD="$PLAYIT_BIN/playitd"
PLAYIT_CLI="$PLAYIT_BIN/playit-cli"
PLAYIT_SECRET="$PLAYIT_DIR/config.toml"

if [ ! -x "$PLAYITD" ]; then
    echo "[ERROR] playitd not found."
    exit 1
fi

if [ ! -x "$PLAYIT_CLI" ]; then
    echo "[ERROR] playit-cli not found."
    exit 1
fi

# Start daemon first.

if pgrep -x playitd >/dev/null 2>&1; then
    echo "[INFO] Playit daemon is already running."
else
    echo "[INFO] Starting Playit daemon..."

    mkdir -p "$PLAYIT_DIR"

    "$PLAYITD" \
        --secret-path "$PLAYIT_SECRET" \
        >/dev/null 2>&1 &

    sleep 2

    if ! pgrep -x playitd >/dev/null 2>&1; then
        echo "[ERROR] playitd failed to start."
        exit 1
    fi

    echo "[OK] playitd is running."
fi

# CLI handles authentication/provisioning.

echo
echo "[INFO] Starting Playit CLI..."
echo

cd "$PLAYIT_DIR"

exec "$PLAYIT_CLI"
EOF

chmod +x "$PLAYIT_BIN/start-playit"

# ============================================================
# Stop
# ============================================================

cat > "$PLAYIT_BIN/stop-playit" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if pgrep -x playitd >/dev/null 2>&1; then
    echo "[INFO] Stopping Playit..."

    pkill -x playitd || true
    sleep 1

    echo "[OK] Playit stopped."
else
    echo "[INFO] Playit is not running."
fi
EOF

chmod +x "$PLAYIT_BIN/stop-playit"

# ============================================================
# Update
# ============================================================

cat > "$PLAYIT_BIN/update-playit" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

PLAYIT_BIN="$HOME/PlayitTermux/bin"
BASE_URL="https://github.com/playit-cloud/playit-agent/releases/latest/download"

# Detect architecture.

case "$(uname -m)" in
    aarch64|arm64)
        PLAYIT_ARCH="aarch64"
        ;;

    x86_64|amd64)
        PLAYIT_ARCH="amd64"
        ;;

    armv7l|armv7)
        PLAYIT_ARCH="armv7"
        ;;

    i686|i386)
        PLAYIT_ARCH="i686"
        ;;

    *)
        echo "[ERROR] Unsupported architecture: $(uname -m)"
        echo "[ERROR] Supported: aarch64, amd64, armv7, i686"
        exit 1
        ;;
esac

DAEMON_URL="$BASE_URL/playit-linux-$PLAYIT_ARCH"
CLI_URL="$BASE_URL/playit-cli-linux-$PLAYIT_ARCH"

echo "[INFO] Architecture: $(uname -m) -> $PLAYIT_ARCH"

download() {
    local url="$1"
    local output="$2"
    local name="$3"
    local tmp="${output}.tmp"

    rm -f "$tmp"

    echo "[INFO] Updating $name..."

    curl \
        -fL \
        --progress-bar \
        --connect-timeout 20 \
        --max-time 300 \
        --retry 3 \
        --retry-delay 2 \
        -o "$tmp" \
        "$url"

    if [ ! -s "$tmp" ]; then
        rm -f "$tmp"
        echo "[ERROR] $name download failed."
        exit 1
    fi

    chmod +x "$tmp"
    mv "$tmp" "$output"

    echo "[OK] $name updated."
}

# Stop before replacing binaries.

if pgrep -x playitd >/dev/null 2>&1; then
    echo "[INFO] Stopping running Playit..."

    pkill -x playitd || true
    sleep 1
fi

download \
    "$DAEMON_URL" \
    "$PLAYIT_BIN/playitd" \
    "Playit daemon"

download \
    "$CLI_URL" \
    "$PLAYIT_BIN/playit-cli" \
    "Playit CLI"

echo
echo "[OK] Playit update complete."
echo
echo "Run:"
echo "  pt start"
EOF

chmod +x "$PLAYIT_BIN/update-playit"

# ============================================================
# pt command
# ============================================================

cat > "$PLAYIT_BIN/pt" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

PLAYIT_BIN="$HOME/PlayitTermux/bin"

case "${1:-start}" in
    start)
        exec "$PLAYIT_BIN/start-playit"
        ;;

    stop)
        exec "$PLAYIT_BIN/stop-playit"
        ;;

    update)
        exec "$PLAYIT_BIN/update-playit"
        ;;

    *)
        echo "Usage: pt [start|stop|update]"
        exit 1
        ;;
esac
EOF

chmod +x "$PLAYIT_BIN/pt"

# ============================================================
# PRoot shortcut
# ============================================================

cat > /usr/local/bin/pt <<'EOF'
#!/usr/bin/env bash

exec "$HOME/PlayitTermux/bin/pt" "$@"
EOF

chmod +x /usr/local/bin/pt

success "PRoot 'pt' shortcut installed."

# ============================================================
# Termux shortcut
# ============================================================

TERMUX_BIN="/data/data/com.termux/files/usr/bin"

cat > "$TERMUX_BIN/pt" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash

exec proot-distro login debian -- \
    bash -lc '"$HOME/PlayitTermux/bin/pt" "$@"' \
    -- "$@"
EOF

chmod +x "$TERMUX_BIN/pt"

success "Termux 'pt' shortcut installed."

# ============================================================
# Verify
# ============================================================

echo
info "Checking installation..."

if [ -x "$PLAYIT_BIN/playitd" ]; then
    success "playitd installed."
fi

if [ -x "$PLAYIT_BIN/playit-cli" ]; then
    success "playit-cli installed."
fi

if [ -x "$PLAYIT_BIN/pt" ]; then
    success "pt command installed."
fi

if [ -x "/usr/local/bin/pt" ]; then
    success "PRoot shortcut installed."
fi

# ============================================================
# Finish
# ============================================================

echo
echo "============================================================"
echo " PlayitTermux installation complete"
echo "============================================================"
echo
echo "Architecture:"
echo "  $PLAYIT_ARCH"
echo
echo "Storage:"
echo "  $PLAYIT_DIR"
echo
echo "Commands:"
echo "  pt start"
echo "  pt stop"
echo "  pt update"
echo
echo "============================================================"

PROOT

# ============================================================
# Finish
# ============================================================

echo
echo "============================================================"
echo " PlayitTermux setup complete"
echo "============================================================"
echo
echo "Run:"
echo "  pt start"
echo
echo "Commands:"
echo "  pt start"
echo "  pt stop"
echo "  pt update"
echo
echo "============================================================"