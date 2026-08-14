#!/data/data/com.termux/files/usr/bin/bash

set -e

# ==========================================
# Playit.gg CLI Installer/Updater for Termux
# Runtime data lives under ~/PlayitTermux
# ==========================================

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; RESET='\033[0m'

info(){ echo -e "${CYAN}[*]${RESET} $1"; }
success(){ echo -e "${GREEN}[+]${RESET} $1"; }
warning(){ echo -e "${YELLOW}[!]${RESET} $1"; }
error(){ echo -e "${RED}[-]${RESET} $1"; }

PLAYIT_DIR="$HOME/PlayitTermux"
PLAYIT_BIN="$PLAYIT_DIR/bin"
PLAYIT_SECRET="$PLAYIT_DIR/config.toml"
PLAYIT_LOG="$PLAYIT_DIR/playitd.log"
TERMUX_BIN="$PREFIX/bin"

MODE="install"
[ -x "$PLAYIT_BIN/playit" ] && MODE="update"

echo
[ "$MODE" = "update" ] \
    && info "Playit.gg Termux Updater" \
    || info "Playit.gg Termux Installer"
echo

# ------------------------------------------
# Check Termux
# ------------------------------------------

if [ ! -d "/data/data/com.termux" ]; then
    error "This script must be run inside Termux."
    exit 1
fi

# ------------------------------------------
# Check architecture
# ------------------------------------------

ARCH="$(uname -m)"
info "Detected architecture: $ARCH"

case "$ARCH" in
    aarch64|arm64|x86_64)
        success "$ARCH detected."
        ;;
    armv7l|armv8l|i686|x86)
        warning "32-bit architecture detected: $ARCH"
        ;;
    *)
        error "Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

# ------------------------------------------
# Prepare directories
# ------------------------------------------

mkdir -p "$PLAYIT_BIN"

# ------------------------------------------
# Stop daemon before update
# ------------------------------------------

if [ "$MODE" = "update" ] && pgrep -x playitd >/dev/null 2>&1; then
    info "Stopping running playitd..."
    pkill -x playitd || true
    sleep 1
    success "playitd stopped."
fi

# ------------------------------------------
# Update Termux packages
# ------------------------------------------

info "Updating Termux packages..."
pkg update -y
pkg upgrade -y

# ------------------------------------------
# Install TUR repository
# ------------------------------------------

if ! command -v tur-repo >/dev/null 2>&1; then
    info "Installing TUR repository..."
    pkg install tur-repo -y
fi

# ------------------------------------------
# Install / update Playit
# ------------------------------------------

info "Installing/updating Playit..."
pkg install playit -y

command -v playitd >/dev/null 2>&1 || {
    error "playitd was not installed."
    exit 1
}

command -v playit-cli >/dev/null 2>&1 || {
    error "playit-cli was not installed."
    exit 1
}

success "Playit installed successfully."

# ------------------------------------------
# Start helper
# ------------------------------------------

cat > "$PLAYIT_BIN/start-playit" <<EOF
#!/data/data/com.termux/files/usr/bin/bash

PLAYIT_SECRET="$PLAYIT_SECRET"
PLAYIT_LOG="$PLAYIT_LOG"

if pgrep -x playitd >/dev/null 2>&1; then
    echo "Playit daemon is already running."
else
    echo "Starting Playit daemon..."

    nohup playitd \
        --secret-path "\$PLAYIT_SECRET" \
        --log-path "\$PLAYIT_LOG" \
        > /dev/null 2>&1 &

    sleep 2
fi

if pgrep -x playitd >/dev/null 2>&1; then
    echo "playitd is running."
else
    echo "playitd failed to start."
    echo "Check: \$PLAYIT_LOG"
    exit 1
fi

echo "Secret file: \$PLAYIT_SECRET"
echo "Log file:    \$PLAYIT_LOG"
echo
echo "Starting Playit CLI..."

exec playit-cli
EOF

chmod +x "$PLAYIT_BIN/start-playit"

# ------------------------------------------
# Stop helper
# ------------------------------------------

cat > "$PLAYIT_BIN/stop-playit" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash

if pgrep -x playitd >/dev/null 2>&1; then
    pkill -x playitd
    echo "Playit daemon stopped."
else
    echo "Playit daemon is not running."
fi
EOF

chmod +x "$PLAYIT_BIN/stop-playit"

# ------------------------------------------
# Update helper
# ------------------------------------------

cat > "$PLAYIT_BIN/update-playit" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash

curl -fsSL \
    https://raw.githubusercontent.com/FaiBah/PlayitTermux/main/install.sh \
    | bash
EOF

chmod +x "$PLAYIT_BIN/update-playit"

# ------------------------------------------
# Main Playit command
# ------------------------------------------

cat > "$PLAYIT_BIN/playit" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash

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
        echo "Usage: playit [start|stop|update]"
        echo
        echo "Commands:"
        echo "  playit start   Start daemon and CLI"
        echo "  playit stop    Stop daemon"
        echo "  playit update  Update Playit"
        exit 1
        ;;
esac
EOF

chmod +x "$PLAYIT_BIN/playit"

# ------------------------------------------
# Global Termux launcher
# ------------------------------------------

cat > "$TERMUX_BIN/playit" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash

exec "$HOME/PlayitTermux/bin/playit" "$@"
EOF

chmod +x "$TERMUX_BIN/playit"

# ------------------------------------------
# Finish
# ------------------------------------------

echo
[ "$MODE" = "update" ] \
    && success "Playit update complete!" \
    || success "Playit installation complete!"

echo
echo "Data: $PLAYIT_DIR"
echo "  Config: $PLAYIT_SECRET"
echo "  Logs:   $PLAYIT_LOG"
echo
echo "Commands:"
echo "  playit"
echo "  playit start"
echo "  playit stop"
echo "  playit update"
