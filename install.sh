#!/data/data/com.termux/files/usr/bin/bash
set -e

GREEN='\033[0;32m'; CYAN='\033[0;36m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; RESET='\033[0m'
info()    { echo -e "${CYAN}[*]${RESET} $1"; }
success() { echo -e "${GREEN}[+]${RESET} $1"; }
warning() { echo -e "${YELLOW}[!]${RESET} $1"; }
error()   { echo -e "${RED}[-]${RESET} $1"; }

PLAYIT_DIR="$HOME/playit"
PLAYIT_BIN="$PLAYIT_DIR/bin"
PLAYIT_LOG="$PLAYIT_DIR/playitd.log"
PLAYIT_CONFIG="$PLAYIT_DIR/config.toml"
REAL_CONFIG_DIR="$HOME/.config/playit_gg"
REAL_CONFIG="$REAL_CONFIG_DIR/playit.toml"

MODE="install"
if command -v playitd >/dev/null 2>&1 || command -v playit-cli >/dev/null 2>&1; then
    MODE="update"
fi

echo
[ "$MODE" = "update" ] && info "Playit.gg Termux Updater" || info "Playit.gg Termux Installer"
echo

if [ ! -d "/data/data/com.termux" ]; then
    error "This script must be run inside Termux."
    exit 1
fi

ARCH="$(uname -m)"
info "Architecture: $ARCH"

mkdir -p "$PLAYIT_BIN" "$REAL_CONFIG_DIR"

if [ "$MODE" = "update" ] && pgrep -x playitd >/dev/null 2>&1; then
    info "Stopping running playitd..."
    pkill -x playitd || true
    sleep 1
fi

info "Updating Termux packages..."
pkg update -y
pkg upgrade -y

if ! command -v tur-repo >/dev/null 2>&1; then
    info "Installing TUR repository..."
    pkg install tur-repo -y
fi

info "Installing/updating Playit..."
pkg install playit -y

command -v playitd >/dev/null 2>&1 || { error "playitd was not installed."; exit 1; }
command -v playit-cli >/dev/null 2>&1 || { error "playit-cli was not installed."; exit 1; }
success "playitd and playit-cli installed."

# Migrate legacy config/log locations
[ -f "$HOME/config.toml" ] && [ ! -e "$REAL_CONFIG" ] && mv "$HOME/config.toml" "$REAL_CONFIG"
[ -f "$PLAYIT_CONFIG" ] && [ ! -L "$PLAYIT_CONFIG" ] && [ ! -e "$REAL_CONFIG" ] && mv "$PLAYIT_CONFIG" "$REAL_CONFIG"
if [ -e "$REAL_CONFIG" ] || [ -L "$PLAYIT_CONFIG" ]; then
    ln -sf "$REAL_CONFIG" "$PLAYIT_CONFIG"
fi
[ -f "$HOME/playitd.log" ] && [ ! -f "$PLAYIT_LOG" ] && mv "$HOME/playitd.log" "$PLAYIT_LOG"

# Helper scripts
cat > "$PLAYIT_BIN/start-playit" <<EOF
#!/data/data/com.termux/files/usr/bin/bash
mkdir -p "\$HOME/playit"
if pgrep -x playitd >/dev/null 2>&1; then
    echo "Playit daemon is already running."
else
    echo "Starting Playit daemon..."
    nohup playitd > "$PLAYIT_LOG" 2>&1 &
    sleep 2
fi
pgrep -a playitd || echo "playitd is not running."
echo "Starting Playit CLI..."
playit-cli
REAL_CONFIG="$REAL_CONFIG"
[ -f "\$REAL_CONFIG" ] && ln -sf "\$REAL_CONFIG" "$PLAYIT_CONFIG"
EOF
chmod +x "$PLAYIT_BIN/start-playit"

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

cat > "$PLAYIT_BIN/update-playit" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
curl -sL https://raw.githubusercontent.com/FaiBah/playit-termux-installer/main/install.sh | bash
EOF
chmod +x "$PLAYIT_BIN/update-playit"

# PATH + alias (idempotent)
grep -qF 'export PATH="$HOME/playit/bin:$PATH"' "$HOME/.bashrc" 2>/dev/null || \
    echo 'export PATH="$HOME/playit/bin:$PATH"' >> "$HOME/.bashrc"
export PATH="$PLAYIT_BIN:$PATH"

grep -qF 'alias playit="$HOME/playit/bin/start-playit"' "$HOME/.bashrc" 2>/dev/null || \
    echo 'alias playit="$HOME/playit/bin/start-playit"' >> "$HOME/.bashrc"

echo
success "$([ "$MODE" = "update" ] && echo "Update" || echo "Installation") complete!"
echo
echo "Data: $PLAYIT_DIR"
echo "Commands: playit | start-playit | stop-playit | update-playit"
echo

read -r -p "Start Playit now? [Y/n]: " ANSWER
if [ "$ANSWER" = "n" ] || [ "$ANSWER" = "N" ]; then
    info "Done."
else
    if pgrep -x playitd >/dev/null 2>&1; then
        warning "playitd is already running."
    else
        nohup playitd > "$PLAYIT_LOG" 2>&1 &
        sleep 2
    fi
    playit-cli
    if [ -f "$REAL_CONFIG" ]; then
        ln -sf "$REAL_CONFIG" "$PLAYIT_CONFIG"
    fi
fi
