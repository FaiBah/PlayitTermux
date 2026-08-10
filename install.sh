#!/data/data/com.termux/files/usr/bin/bash

set -e

# ==========================================
# Playit.gg CLI Installer/Updater for Termux
# All runtime data lives under ~/playit
# ==========================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RESET='\033[0m'

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
if [ "$MODE" = "update" ]; then
    info "Playit.gg Termux Updater"
else
    info "Playit.gg Termux Installer"
fi
echo

# ------------------------------------------
# Check Termux + architecture
# ------------------------------------------

if [ ! -d "/data/data/com.termux" ]; then
    error "This script must be run inside Termux."
    exit 1
fi

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

mkdir -p "$PLAYIT_BIN" "$REAL_CONFIG_DIR"

# ------------------------------------------
# Stop daemon before updating (if running)
# ------------------------------------------

if [ "$MODE" = "update" ] && pgrep -x playitd >/dev/null 2>&1; then
    info "Stopping running playitd before update..."
    pkill -x playitd || true
    sleep 1
    success "playitd stopped."
fi

# ------------------------------------------
# Update Termux, install/update Playit
# ------------------------------------------

info "Updating Termux packages..."
pkg update -y
pkg upgrade -y

if ! command -v tur-repo >/dev/null 2>&1; then
    info "Installing TUR repository..."
    pkg install tur-repo -y
fi

info "Installing/updating Playit..."
pkg install playit -y

if ! command -v playitd >/dev/null 2>&1; then
    error "playitd was not installed."
    exit 1
fi
if ! command -v playit-cli >/dev/null 2>&1; then
    error "playit-cli was not installed."
    exit 1
fi
success "playitd and playit-cli installed."

# ------------------------------------------
# Link playit's real config into ~/playit
# playit-cli/playitd always write to
# ~/.config/playit_gg/playit.toml, so we
# symlink that real file into ~/playit.
# ------------------------------------------

if [ -f "$HOME/config.toml" ] && [ ! -e "$REAL_CONFIG" ]; then
    info "Moving legacy config.toml into $REAL_CONFIG_DIR..."
    mv "$HOME/config.toml" "$REAL_CONFIG"
fi

if [ -f "$PLAYIT_CONFIG" ] && [ ! -L "$PLAYIT_CONFIG" ] && [ ! -e "$REAL_CONFIG" ]; then
    mv "$PLAYIT_CONFIG" "$REAL_CONFIG"
fi

if [ -e "$REAL_CONFIG" ] || [ -L "$PLAYIT_CONFIG" ]; then
    ln -sf "$REAL_CONFIG" "$PLAYIT_CONFIG"
fi

if [ -f "$HOME/playitd.log" ] && [ ! -f "$PLAYIT_LOG" ]; then
    mv "$HOME/playitd.log" "$PLAYIT_LOG"
fi

# ------------------------------------------
# Helper scripts
# ------------------------------------------

cat > "$PLAYIT_BIN/start-playit" <<EOF
#!/data/data/com.termux/files/usr/bin/bash

PLAYIT_LOG="$PLAYIT_LOG"
PLAYIT_CONFIG="$PLAYIT_CONFIG"
REAL_CONFIG="$REAL_CONFIG"

mkdir -p "$PLAYIT_DIR"

if pgrep -x playitd >/dev/null 2>&1; then
    echo "Playit daemon is already running."
else
    echo "Starting Playit daemon..."
    nohup playitd > "\$PLAYIT_LOG" 2>&1 &
    sleep 2
fi

pgrep -a playitd || echo "playitd is not running."
echo "Log file: \$PLAYIT_LOG"
echo "Config file: \$PLAYIT_CONFIG"

echo "Starting Playit CLI..."
playit-cli

if [ -f "\$REAL_CONFIG" ]; then
    ln -sf "\$REAL_CONFIG" "\$PLAYIT_CONFIG"
fi
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

# ------------------------------------------
# PATH + alias (idempotent)
# ------------------------------------------

if ! grep -qF 'export PATH="$HOME/playit/bin:$PATH"' "$HOME/.bashrc" 2>/dev/null; then
    echo 'export PATH="$HOME/playit/bin:$PATH"' >> "$HOME/.bashrc"
fi
export PATH="$PLAYIT_BIN:$PATH"

if ! grep -qF 'alias playit="$HOME/playit/bin/start-playit"' "$HOME/.bashrc" 2>/dev/null; then
    echo 'alias playit="$HOME/playit/bin/start-playit"' >> "$HOME/.bashrc"
fi

# ------------------------------------------
# Finish
# ------------------------------------------

echo
if [ "$MODE" = "update" ]; then
    success "Playit update complete!"
else
    success "Playit installation complete!"
fi
echo
echo "Data: $PLAYIT_DIR"
echo "  Config: $PLAYIT_CONFIG (symlink to $REAL_CONFIG)"
echo "  Logs:   $PLAYIT_LOG"
echo
echo "Commands (restart Termux or 'source ~/.bashrc' to pick up PATH/alias):"
echo "  playit | start-playit | stop-playit | update-playit"
echo

# ------------------------------------------
# Start now
# ------------------------------------------

read -r -p "Start Playit now? [Y/n]: " ANSWER

if [ "$ANSWER" = "n" ] || [ "$ANSWER" = "N" ]; then
    info "Finished without starting Playit."
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
