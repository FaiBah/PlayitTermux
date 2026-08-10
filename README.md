# Playit.gg Termux Installer

A single-script installer and updater for running [playit.gg](https://playit.gg) (`playitd` + `playit-cli`) on Termux, with all runtime data organized under one `~/playit` folder.

## Features

- One-command install and update — the script detects which one you need
- Clean, self-contained layout: config, logs, and helper scripts all live under `~/playit`
- Simple `playit` alias to launch the daemon and CLI from anywhere in Termux
- Safe to re-run at any time to update to the latest version

## Installation

```bash
curl -sL https://raw.githubusercontent.com/FaiBah/playit-termux-installer/main/install.sh | bash
```

This installs `playitd` and `playit-cli`, sets up helper scripts, and adds a `playit` alias to your shell.

## Usage

After installation, restart Termux (or run `source ~/.bashrc`), then simply run:

```bash
playit
```

This starts the Playit daemon and opens the CLI.

## Updating

Run the same install command again, or use the built-in updater:

```bash
update-playit
```

The script detects your existing installation, stops the daemon if it's running, and reinstalls the latest version.

## Layout on Device

```
~/playit/
├── config.toml
├── playitd.log
└── bin/
    ├── start-playit
    ├── stop-playit
    └── update-playit
```

## Commands

| Command | Purpose |
|---|---|
| `playit` | Quick alias to start the daemon and CLI |
| `start-playit` | Starts `playitd` and opens `playit-cli` |
| `stop-playit` | Stops `playitd` |
| `update-playit` | Re-downloads and runs the latest installer |

## What the Installer Does

- Detects device architecture (arm64, arm, x86_64, x86)
- Updates Termux packages
- Installs the TUR repository if missing
- Installs or updates `playit` via `pkg`
- Verifies `playitd` and `playit-cli` are available
- Creates `~/playit` with helper scripts and log/config storage
- Adds `~/playit/bin` to `PATH` and a `playit` alias to your shell profile
- Optionally starts Playit immediately after install or update

## Requirements

- Termux (the script exits if not run inside Termux)

## License

MIT
