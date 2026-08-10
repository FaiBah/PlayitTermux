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
BOLD='\033[1m'
RESET='\033[0m'

info() {
    echo -e "${CYAN}[*]${RESET} $1"
}

success() {
    echo -e "${GREEN}[+]${RESET} $1"
}

warning() {
    echo -e "${YELLOW}[!]${RESET} $1"
}

error() {
    echo -e "${RED}[-]${RESET} $1"
}

PLAYIT_DIR="$HOME/playit"
PLAYIT_BIN="$PLAYIT_DIR/bin"
PLAYIT_LOG="$PLAYIT_DIR/playitd.log"
PLAYIT_CONFIG="$PLAYIT_DIR/config.toml"

MODE="install"
if command -v playitd >/dev/null 2>&1 || command -v playit-cli >/dev/null 2>&1; then
    MODE="update"
fi

echo
echo -e "${BOLD}==========================================${RESET}"
if [ "$MODE" = "update" ]; then
    echo -e "${BOLD}       Playit.gg Termux Updater${RESET}"
else
    echo -e "${BOLD}       Playit.gg Termux Installer${RESET}"
fi
echo -e "${BOLD}==========================================${RESET}"
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
    aarch64|arm64)
        success "ARM64 detected."
        ;;
    armv7l|armv8l)
        warning "32-bit ARM detected."
        ;;
    x86_64)
        success "x86_64 detected."
        ;;
    i686|x86)
        warning "32-bit x86 detected."
        ;;
    *)
        error "Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

# ------------------------------------------
# Create ~/playit structure
# ------------------------------------------

mkdir -p "$PLAYIT_BIN"

# ------------------------------------------
# Stop daemon before updating (if running)
# ------------------------------------------

if [ "$MODE" = "update" ]; then
    if pgrep -x playitd >/dev/null 2>&1; then
        info "Stopping running playitd before update..."
        pkill -x playitd || true
        sleep 1
        success "playitd stopped."
    fi
fi

# ------------------------------------------
# Update Termux
# ------------------------------------------

info "Updating Termux packages..."

pkg update -y
pkg upgrade -y

# ------------------------------------------
# Install/ensure TUR repository
# ------------------------------------------

if ! command -v tur-repo >/dev/null 2>&1; then
    info "Installing TUR repository..."
    pkg install tur-repo -y
else
    success "TUR repository already installed."
fi

# ------------------------------------------
# Install/Update Playit
# ------------------------------------------

if [ "$MODE" = "update" ]; then
    info "Reinstalling/updating Playit..."
else
    info "Installing Playit..."
fi

pkg install playit -y

# ------------------------------------------
# Verify playitd
# ------------------------------------------

if command -v playitd >/dev/null 2>&1; then
    PLAYITD="$(command -v playitd)"
    success "playitd found: $PLAYITD"
else
    error "playitd was not installed."
    exit 1
fi

# ------------------------------------------
# Verify playit-cli
# ------------------------------------------

if command -v playit-cli >/dev/null 2>&1; then
    PLAYITCLI="$(command -v playit-cli)"
    success "playit-cli found: $PLAYITCLI"
else
    error "playit-cli was not installed."
    exit 1
fi

# ------------------------------------------
# Show versions/help
# ------------------------------------------

echo
info "Playit daemon:"
playitd --version 2>/dev/null || true

echo
info "Playit CLI:"
playit-cli --version 2>/dev/null || true

# ------------------------------------------
# Link playit's real config into ~/playit
# playit-cli/playitd ignore --config and always
# write to ~/.config/playit_gg/playit.toml, so we
# symlink that real file into ~/playit instead.
# ------------------------------------------

REAL_CONFIG_DIR="$HOME/.config/playit_gg"
REAL_CONFIG="$REAL_CONFIG_DIR/playit.toml"

mkdir -p "$REAL_CONFIG_DIR"

if [ -f "$HOME/config.toml" ] && [ ! -e "$REAL_CONFIG" ]; then
    info "Moving legacy config.toml into $REAL_CONFIG_DIR..."
    mv "$HOME/config.toml" "$REAL_CONFIG"
fi

if [ -f "$PLAYIT_CONFIG" ] && [ ! -L "$PLAYIT_CONFIG" ] && [ ! -e "$REAL_CONFIG" ]; then
    info "Moving existing $PLAYIT_CONFIG to real location..."
    mv "$PLAYIT_CONFIG" "$REAL_CONFIG"
fi

# (Re)create the symlink so ~/playit/config.toml always points at the real file
if [ -e "$REAL_CONFIG" ] || [ -L "$PLAYIT_CONFIG" ]; then
    ln -sf "$REAL_CONFIG" "$PLAYIT_CONFIG"
fi

if [ -f "$HOME/playitd.log" ] && [ ! -f "$PLAYIT_LOG" ]; then
    mv "$HOME/playitd.log" "$PLAYIT_LOG"
fi

# ------------------------------------------
# Create helper scripts inside ~/playit/bin
# ------------------------------------------

cat > "$PLAYIT_BIN/start-playit" <<EOF
#!/data/data/com.termux/files/usr/bin/bash

PLAYIT_DIR="\$HOME/playit"
PLAYIT_LOG="\$PLAYIT_DIR/playitd.log"
PLAYIT_CONFIG="\$PLAYIT_DIR/config.toml"

mkdir -p "\$PLAYIT_DIR"

if pgrep -x playitd >/dev/null 2>&1; then
    echo "Playit daemon is already running."
else
    echo "Starting Playit daemon..."
    nohup playitd > "\$PLAYIT_LOG" 2>&1 &
    sleep 2
fi

echo
echo "Playit daemon status:"
pgrep -a playitd || echo "playitd is not running."

echo
echo "Log file: \$PLAYIT_LOG"
echo "Config file: \$PLAYIT_CONFIG"

echo
echo "Starting Playit CLI..."
playit-cli

# Re-link config in ~/playit in case CLI just created it
REAL_CONFIG="\$HOME/.config/playit_gg/playit.toml"
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
# Re-downloads and runs the latest installer/updater script.
curl -sL https://raw.githubusercontent.com/FaiBah/playit-termux-installer/main/install.sh | bash
EOF

chmod +x "$PLAYIT_BIN/update-playit"

# ------------------------------------------
# Add ~/playit/bin to PATH
# ------------------------------------------

case ":$PATH:" in
    *":$PLAYIT_BIN:"*)
        ;;
    *)
        echo "export PATH=\"\$HOME/playit/bin:\$PATH\"" >> "$HOME/.bashrc"
        export PATH="$PLAYIT_BIN:$PATH"
        ;;
esac

# ------------------------------------------
# Add 'playit' alias to launch start-playit
# ------------------------------------------

if ! grep -q "alias playit=" "$HOME/.bashrc" 2>/dev/null; then
    echo "alias playit=\"\$HOME/playit/bin/start-playit\"" >> "$HOME/.bashrc"
fi
alias playit="$PLAYIT_BIN/start-playit"

# ------------------------------------------
# Finish
# ------------------------------------------

echo
echo -e "${GREEN}==========================================${RESET}"
if [ "$MODE" = "update" ]; then
    echo -e "${GREEN}       Playit update complete!${RESET}"
else
    echo -e "${GREEN}       Playit installation complete!${RESET}"
fi
echo -e "${GREEN}==========================================${RESET}"
echo

echo "All Playit data lives in: $PLAYIT_DIR"
echo "  Config: $PLAYIT_CONFIG (symlink to $REAL_CONFIG)"
echo "  Logs:   $PLAYIT_LOG"
echo "  Helper scripts: $PLAYIT_BIN"
echo
echo "Commands (restart Termux or 'source ~/.bashrc' to pick up PATH/alias):"
echo
echo "  Start (short alias):"
echo "    playit"
echo
echo "  Start (full command):"
echo "    start-playit"
echo
echo "  Stop:"
echo "    stop-playit"
echo
echo "  Update:"
echo "    update-playit"
echo
echo "  Manual daemon:"
echo "    playitd &"
echo
echo "  CLI:"
echo "    playit-cli"
echo

# ------------------------------------------
# Start now
# ------------------------------------------

read -r -p "Start Playit now? [Y/n]: " ANSWER

case "$ANSWER" in
    n|N)
        echo
        info "Finished without starting Playit."
        ;;
    *)
        echo
        info "Starting Playit daemon..."

        if pgrep -x playitd >/dev/null 2>&1; then
            warning "playitd is already running."
        else
            nohup playitd > "$PLAYIT_LOG" 2>&1 &
            sleep 2
        fi

        echo
        info "Opening Playit CLI..."
        echo

        playit-cli

        # Re-link config in case first login just created it
        if [ -f "$REAL_CONFIG" ]; then
            ln -sf "$REAL_CONFIG" "$PLAYIT_CONFIG"
        fi
        ;;
esac
