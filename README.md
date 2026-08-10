# 🎮 Playit.gg Termux Installer

One-command install and update for [playit.gg](https://playit.gg) on Termux. Everything lives in a single `~/playit` folder.

---

## 🚀 Install

```bash
curl -sL https://raw.githubusercontent.com/FaiBah/playit-termux-installer/main/install.sh | bash
```

## ▶️ Run

```bash
playit
```

## 🔄 Update

```bash
update-playit
```

---

## 📁 Layout

```
~/playit/
├── config.toml
├── playitd.log
└── bin/
    ├── start-playit
    ├── stop-playit
    └── update-playit
```

## 📋 Commands

| Command | Action |
|---|---|
| `playit` | Start daemon + CLI |
| `start-playit` | Same as above |
| `stop-playit` | Stop daemon |
| `update-playit` | Update to latest |

---

## 🗑️ Uninstall

```bash
stop-playit
pkg uninstall playit -y
rm -rf ~/playit ~/.config/playit_gg
sed -i '/playit\/bin/d; /alias playit=/d' ~/.bashrc
```

---

## ✅ Requirements

- Termux

## 📄 License

MIT
