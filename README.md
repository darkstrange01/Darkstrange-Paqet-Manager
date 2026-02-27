<div align="center">

```
     ____  ___    ____  __ _________________  ___    _   ______________
    / __ \/   |  / __ \/ //_/ ___/_  __/ __ \/   |  / | / / ____/ ____/
  / / / / /| | / /_/ / ,<  \__ \ / / / /_/ / /| | /  |/ / / __/ __/
 / /_/ / ___ |/ _, _/ /| |___/ // / / _, _/ ___ |/ /|  / /_/ / /___
/_____/_/  |_/_/ |_/_/ |_/____//_/ /_/ |_/_/  |_/_/ |_/\____/_____/
```

**A clean, minimal shell script for managing [Paqet](https://github.com/hanselime/paqet) raw packet tunnels**

---

[![GitHub release](https://img.shields.io/github/v/release/darkstrange01/Darkstrange-Paqet-Manager?style=flat-square)](https://github.com/darkstrange01/Darkstrange-Paqet-Manager/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=flat-square)](LICENSE)
[![Powered by Paqet](https://img.shields.io/badge/Powered%20by-Paqet-blue?style=flat-square)](https://github.com/hanselime/paqet)
[![Shell](https://img.shields.io/badge/Shell-Bash-green?style=flat-square)](darkstrange-paqet.sh)

[🇮🇷 فارسی](README-fa.md)

</div>

---

## 📋 Table of Contents

- [Overview](#-overview)
- [Features](#-features)
- [Requirements](#-requirements)
- [Quick Start](#-quick-start)
- [Usage Guide](#-usage-guide)
- [Configuration](#-configuration)
- [Donation](#-donation)

---

## 📖 Overview

**Darkstrange Paqet Manager** is a lightweight Bash script that makes setting up and managing [Paqet](https://github.com/hanselime/paqet) raw packet tunnels simple and fast.

Paqet is a raw packet-level tunneling tool designed to bypass network restrictions. This manager wraps it in an interactive menu so you don't need to write YAML configs or manage systemd services manually.

> **Credit:** The core tunneling engine is [Paqet](https://github.com/hanselime/paqet) by [@hanselime](https://github.com/hanselime). This script is only a management layer.

---

## ✨ Features

- 🚀 **Auto-install** Paqet core binary from GitHub releases
- 🔄 **Update / downgrade** Paqet to any available version
- 🌍 **Server** (foreign) and 🇮🇷 **Client** (Iran) mode support
- 📡 **TCP**, **UDP**, and **TCP/UDP** forward protocol support
- 🔀 **Port mapping** — e.g. `2020=2021`, `443,8080`
- ⚡ **KCP modes** — `fast`, `fast2`, `fast3`
- ⏰ **Cron job management** — scheduled auto-restart per tunnel or all
- 🔁 **Auto-import** existing `/etc/paqet/*.yaml` configs
- 🛠️ **Edit** any tunnel setting without recreating it
- 📋 **Live logs** via journalctl per service

---

## 📦 Requirements

| Requirement           | Notes                             |
| --------------------- | --------------------------------- |
| Linux (Ubuntu 20.04+) | Debian-based recommended          |
| Root access           | Required                          |
| `curl` or `wget`      | For downloading Paqet binary      |
| `systemd`             | For service management            |
| `cron`                | For scheduled restarts (optional) |

---

## 🚀 Quick Start

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/darkstrange01/Darkstrange-Paqet-Manager/main/darkstrange-paqet.sh)
```

Or with wget:

```bash
bash <(wget -qO- https://raw.githubusercontent.com/darkstrange01/Darkstrange-Paqet-Manager/main/darkstrange-paqet.sh)
```

The script will automatically install the latest Paqet binary and launch the interactive menu.

---

## 📚 Usage Guide

### Setting up an Iran ↔ Foreign tunnel

**Step 1 — On the Iran server (Client)**

1. Run the script
2. Select `1) Configure a new tunnel`
3. Choose `1) Iran Server (Client)`
4. Enter your local IP (auto-detected), the foreign server IP, and tunnel port
5. A 64-character key will be generated — **save it**
6. Enter the ports you want to forward (e.g. `443,8080`)
7. Select protocol and KCP mode

**Step 2 — On the Foreign server (Server)**

1. Run the script
2. Select `1) Configure a new tunnel`
3. Choose `2) Foreign Server (Server)`
4. Enter your local IP, the same tunnel port
5. Enter the key generated in Step 1

That's it. Both services will start automatically.

---

### Port formats

```
443           → forward port 443 to 127.0.0.1:443
443,8080      → forward multiple ports
2020=2021     → forward port 2020 to local 2021
443,2020=2021 → combination
```

---

## ⚙️ Configuration

| Path                                  | Description                  |
| ------------------------------------- | ---------------------------- |
| `/etc/darkstrange-paqet/tunnels.conf` | Tunnel registry              |
| `/etc/paqet/<name>.yaml`              | Paqet YAML config per tunnel |
| `/etc/systemd/system/<name>.service`  | Systemd service per tunnel   |
| `/var/log/darkstrange-paqet.log`      | Script activity log          |

---

## 💖 Donation

If this project saved you time, consider supporting development:

| Network               | Address                                            |
| --------------------- | -------------------------------------------------- |
| **BNB (BEP20 / BSC)** | `0x5955968Cc111f7098ecaD6C50F99D95C637670A5`       |
| **USDT (ERC20)**      | `0x5955968Cc111f7098ecaD6C50F99D95C637670A5`       |
| **TRON (TRX)**        | `TUp1cT2s2XUarchmV2JwFp8QqV9ueHwg89`               |
| **TON**               | `UQA_6LvNdtXRjDY_Ts4OYXmNTrXpRV5ETJHj1KbIt-RrDR9v` |

Thank you for your support! 💖

---

## 📄 License

MIT — see [LICENSE](LICENSE)

---

<div align="center">
Made with ❤️ for Internet freedom
</div>
