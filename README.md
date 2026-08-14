<div align="center">

# 🎮 PlayitTermux

**Run the [Playit.gg](https://playit.gg) agent on Android — no root required.**

A one-command installer that sets up Playit inside a Debian PRoot environment on Termux, letting you expose local game servers and services to the internet directly from your phone.

[![Platform](https://img.shields.io/badge/platform-Termux-3DDC84?logo=android&logoColor=white)](https://termux.dev)
[![Shell](https://img.shields.io/badge/shell-Bash-4EAA25?logo=gnubash&logoColor=white)](https://www.gnu.org/software/bash/)
[![Base](https://img.shields.io/badge/base-Debian-A81D33?logo=debian&logoColor=white)](https://www.debian.org)
[![License](https://img.shields.io/badge/license-MIT-blue)](#license)

</div>

---

## 📖 Overview

`PlayitTermux` automates the entire process of installing and running the [Playit](https://playit.gg) tunnel agent on an Android device via Termux. It provisions an isolated Debian environment (using `proot-distro`), downloads the correct Playit binaries for your device's architecture, and installs a simple `pt` command you can run from either Termux or inside the Debian PRoot.

No root access, no manual dependency wrangling — just run the script and go.

---

## ✨ Features

| Feature | Description |
|---|---|
| 🔍 **Auto architecture detection** | Detects `aarch64`, `amd64`, `armv7`, or `i686` and fetches the matching binary |
| 📦 **Isolated environment** | Installs into a Debian PRoot container, keeping your Termux base clean |
| ⚙️ **Simple CLI** | Adds a global `pt` command with `start`, `stop`, and `update` subcommands |
| 🔄 **Idempotent setup** | Safe to re-run — skips steps that are already complete |
| 🛡️ **Safety checks** | Refuses to run outside Termux or as root, preventing misconfiguration |
| 🧹 **Clean process handling** | Automatically stops any running daemon before install or update |

---

## 📋 Requirements

- An Android device with [Termux](https://termux.dev) installed (F-Droid build recommended)
- Active internet connection
- ~150 MB of free storage

---

## 🚀 Installation

Run the following inside Termux:

```bash
curl -fsSL https://raw.githubusercontent.com/FaiBah/PlayitTermux/main/setup.sh -o setup.sh
bash setup.sh
```

Or run it directly in one line:

```bash
curl -fsSL https://raw.githubusercontent.com/FaiBah/PlayitTermux/main/setup.sh | bash
```

The installer will:

1. Update Termux packages and install `proot-distro`
2. Install a Debian PRoot environment (if not already present)
3. Download the Playit daemon (`playitd`) and CLI (`playit-cli`)
4. Generate `start`, `stop`, and `update` scripts
5. Register the global `pt` command in both Termux and Debian

---

## 🕹️ Usage

Once installed, manage Playit from **anywhere in Termux** using the `pt` command:

```bash
pt start    # Start the Playit daemon and open the CLI
pt stop     # Stop the running Playit daemon
pt update   # Download the latest Playit binaries
```

### First-time setup

On first launch, `playit-cli` will prompt you to authenticate and claim your agent via a browser link:

```bash
pt start
```

Follow the on-screen link to link the agent to your [Playit.gg](https://playit.gg) account, then configure your tunnels from the Playit dashboard.

---

## 📁 File Structure

After installation, the following layout is created inside the Debian PRoot:

```
~/PlayitTermux/
├── bin/
│   ├── playitd          # Playit daemon binary
│   ├── playit-cli        # Playit CLI binary
│   ├── start-playit       # Start script
│   ├── stop-playit        # Stop script
│   ├── update-playit      # Update script
│   └── pt                 # Unified command wrapper
└── config.toml            # Playit agent secret/config (generated on first run)
```

---

## ⚠️ Disclaimer

This project is an independent installer/wrapper script and is **not officially affiliated with or endorsed by Playit.gg**. All Playit binaries are downloaded directly from the [official Playit GitHub releases](https://github.com/playit-cloud/playit-agent). Use in accordance with Playit's terms of service.

---

## 🗑️ Uninstallation

To completely remove PlayitTermux and all its components, follow these steps.

### 1. Stop the running daemon

```bash
pt stop
```

### 2. Remove PlayitTermux files from the Debian PRoot

```bash
proot-distro login debian -- bash -c '
    rm -rf "$HOME/PlayitTermux"
    rm -f /usr/local/bin/pt
'
```

### 3. Remove the Termux-level `pt` shortcut

```bash
rm -f "$PREFIX/bin/pt"
```

### 4. (Optional) Remove the entire Debian PRoot

If you no longer need the Debian environment at all:

```bash
proot-distro remove debian
```

> ⚠️ This deletes the entire Debian container, including any other data stored inside it — not just Playit.

### 5. (Optional) Remove `proot-distro`

If `proot-distro` was only installed for this project and isn't needed elsewhere:

```bash
pkg uninstall -y proot-distro
```

### Verify removal

```bash
which pt        # should return nothing
pt start        # should return "command not found"
```

---

## 📄 License

This project is licensed under the **MIT License** — see the [LICENSE](LICENSE) file for details.