# Playit.gg Termux Installer

Install and update [playit.gg](https://playit.gg) (`playitd` + `playit-cli`) on Termux with one script. All runtime data (config, logs, helper scripts) lives in a single `~/playit` folder on the device.

## Usage

```bash
curl -sL https://raw.githubusercontent.com/FaiBah/playit-termux-installer/main/install.sh | bash
```

Run it again any time to update — it detects an existing install, stops `playitd` if running, and reinstalls via `pkg`.

## Layout on device (`~/playit`)

```
~/playit/
├── config.toml       # symlink -> ~/.config/playit_gg/playit.toml
├── playitd.log       # daemon log
└── bin/
    ├── start-playit
    ├── stop-playit
    └── update-playit
```

`playit-cli`/`playitd` always write their real config to `~/.config/playit_gg/playit.toml` (they ignore config-path flags), so the script keeps `~/playit/config.toml` as a symlink pointing at that real file — you can edit/view it from either path and it's the same file. Logs and helper scripts are physically stored in `~/playit`.

If you're upgrading from an older install that kept `config.toml` / `playitd.log` directly in `$HOME`, the script auto-migrates them.

## What it does

- Detects device architecture (arm64, arm, x86_64, x86)
- Updates Termux packages
- Installs the TUR repository if missing
- Installs/updates `playit` via `pkg`
- Verifies `playitd` and `playit-cli` are on `PATH`
- Creates `~/playit` with `config.toml`, `playitd.log`, and `bin/` helper scripts
- Adds `~/playit/bin` to `PATH`
- Optionally starts Playit immediately after install/update

## Commands

| Command | Purpose |
|---|---|
| `start-playit` | Starts `playitd` (using `~/playit/config.toml` if present) and opens `playit-cli` |
| `stop-playit` | Stops `playitd` |
| `update-playit` | Re-downloads and runs the latest installer |

## Requirements

- Termux (this script exits if not run inside Termux)

## License

MIT
