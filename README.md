# 🎮 Playit.gg Termux Installer

Install, run, and manage [playit.gg](https://playit.gg) on Termux — one script, one command.

- 📦 Auto-installs via TUR repo
- 🗂️ Config + logs in one place (`~/PlayitTermux`)
- ⚡ Simple `playit` command

---

## 🚀 Install

```bash
curl -sL https://raw.githubusercontent.com/FaiBah/PlayitTermux/main/install.sh | bash
```

## ▶️ Run

```bash
playit
```

## 🔄 Update

```bash
playit update
```

---

## 🗂️ Layout

```
~/PlayitTermux/
├── config.toml
├── playitd.log
└── bin/
    ├── playit
    ├── start-playit
    ├── stop-playit
    └── update-playit
```

> Global launcher: `$PREFIX/bin/playit` → forwards to `~/PlayitTermux/bin/playit`

---

## 🕹️ Commands

| Command | Action |
|---|---|
| `playit` | Start daemon + CLI |
| `playit start` | Start daemon + CLI |
| `playit stop` | Stop daemon |
| `playit update` | Update Playit |

---

## 🗑️ Uninstall

**1️⃣ Stop daemon**
```bash
playit stop
```

**2️⃣ Remove package**
```bash
pkg uninstall playit -y
```

**3️⃣ Remove TUR repo** (optional)
```bash
pkg uninstall tur-repo -y
```

**4️⃣ Remove data/config/logs**
```bash
rm -rf ~/PlayitTermux
```

**5️⃣ Remove launcher**
```bash
rm -f $PREFIX/bin/playit
```

**6️⃣ Verify**
```bash
command -v playit-cli playitd playit   # should return nothing
```

**⚡ One-liner**
```bash
playit stop 2>/dev/null; pkg uninstall playit tur-repo -y; rm -rf ~/PlayitTermux; rm -f $PREFIX/bin/playit
```

---

## ✅ Requirements

- Termux
- aarch64 / arm64 / x86_64 (32-bit works, with warning)

## 📄 License

MIT
