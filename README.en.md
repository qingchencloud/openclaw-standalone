# OpenClaw Standalone

**Zero-dependency installer** — No Node.js, no npm, just download and run!

Built and maintained by [QingChenCloud](https://gpt.qt.cool).

[![Build](https://github.com/qingchencloud/openclaw-standalone/actions/workflows/build.yml/badge.svg)](https://github.com/qingchencloud/openclaw-standalone/actions/workflows/build.yml)
[![License: AGPL-3.0](https://img.shields.io/badge/License-AGPL--3.0-blue.svg)](LICENSE)

> **[中文版 →](README.md)**

---

## Why This Project?

[OpenClaw](https://github.com/openclaw/openclaw) is a powerful AI agent engine, but installing it via `npm install -g` has several pain points:

- **Slow downloads**: npm fetches hundreds of dependencies from remote registries
- **High prerequisites**: Requires Node.js 22+, npm, Git, and may fail on native module compilation
- **Not beginner-friendly**: Permission errors, PATH issues, and network failures frustrate non-technical users

**OpenClaw Standalone** solves all of this:

- ✅ **Zero dependencies**: Bundled Node.js runtime and all pre-compiled dependencies
- ✅ **Instant setup**: Download → Extract → Run
- ✅ **Cross-platform**: Windows / macOS / Linux / Raspberry Pi
- ✅ **Windows installer**: Professional `.exe` setup wizard
- ✅ **Dual editions**: Both official and Chinese-localized versions available

---

## Choose Your Edition

This project provides **two editions** of pre-built packages, built from the same repository and CI pipeline:

| Edition | NPM Package | File Prefix | Description |
|---------|-------------|-------------|-------------|
| **Official** | `openclaw` | `openclaw-*` | English UI, same as official npm package |
| **Chinese** | `@qingchencloud/openclaw-zh` | `openclaw-zh-*` | Chinese-localized UI and prompts |

Both editions are functionally identical — the only difference is the interface language.

---

## Installation

### Windows (Recommended: Setup Wizard)

1. Download from [Releases](https://github.com/qingchencloud/openclaw-standalone/releases):
   - Official: `openclaw-*-win-x64-setup.exe`
   - Chinese: `openclaw-zh-*-win-x64-setup.exe`
2. Run the installer
3. Open a terminal and type `openclaw`

> You can also download the `.zip` portable version — extract and add the directory to your PATH.

### macOS / Linux (One-Line Install)

```bash
# Official edition (default)
curl -fsSL https://dl.qrj.ai/openclaw/install.sh | EDITION=en bash

# Chinese edition
curl -fsSL https://dl.qrj.ai/openclaw/install.sh | bash
```

Supported platforms:
- macOS ARM64 (Apple Silicon / M1-M4)
- macOS x64 (Intel)
- Linux x64
- Linux ARM64 (Raspberry Pi 4/5, ARM servers)

### Manual Installation

1. Download the archive for your platform from [Releases](https://github.com/qingchencloud/openclaw-standalone/releases)
2. Extract to any directory
3. Add the directory to your system PATH
4. Verify: `openclaw --version`

---

## Downloads

### Official Edition (`openclaw-*`)

| Platform | Architecture | Format | Note |
|----------|-------------|--------|------|
| Windows | x64 | `.exe` installer | Guided setup, auto-configures PATH |
| Windows | x64 | `.zip` | Portable, extract & run |
| macOS | ARM64 (Apple Silicon) | `.tar.gz` | Extract & run |
| macOS | x64 (Intel) | `.tar.gz` | Extract & run |
| Linux | x64 | `.tar.gz` | Extract & run |
| Linux | ARM64 | `.tar.gz` | Raspberry Pi, ARM servers |

### Chinese Edition (`openclaw-zh-*`)

| Platform | Architecture | Format | Note |
|----------|-------------|--------|------|
| Windows | x64 | `.exe` installer | Guided setup |
| Windows | x64 | `.zip` | Portable |
| macOS | ARM64 (Apple Silicon) | `.tar.gz` | Extract & run |
| macOS | x64 (Intel) | `.tar.gz` | Extract & run |
| Linux | x64 | `.tar.gz` | Extract & run |
| Linux | ARM64 | `.tar.gz` | Raspberry Pi, ARM servers |

---

## Quick Start

```bash
# Show help
openclaw --help

# Initial setup
openclaw setup

# Start AI Gateway
openclaw gateway

# Check status
openclaw status
```

### GUI Management Panel

Install [ClawPanel](https://github.com/qingchencloud/clawpanel) for a visual management interface:
- Model configuration
- Agent management
- Messaging channels (Slack, Discord, etc.)
- Docker fleet orchestration
- Scheduled tasks, skill marketplace, and more

---

## How It Works

Core idea: **Pre-compile all native modules on CI runners for each platform, then bundle Node.js runtime + complete node_modules into a self-contained distribution.**

```
GitHub Actions CI Matrix (2 editions × 4 platforms = 8 parallel builds)

Official (en):                          Chinese (zh):
├── windows-latest → zip + .exe         ├── windows-latest → zip + .exe
├── macos-15       → tar.gz             ├── macos-15       → tar.gz
├── ubuntu-latest  → tar.gz             ├── ubuntu-latest  → tar.gz
└── ubuntu-arm64   → tar.gz             └── ubuntu-arm64   → tar.gz
```

Each platform package contains:
- `node` / `node.exe` — Node.js runtime
- `openclaw` / `openclaw.cmd` — CLI entry point
- `node_modules/` — All dependencies (with pre-compiled native modules)
- `VERSION` — Version and edition info

### Building Locally

```bash
# Windows - Official edition
powershell -ExecutionPolicy Bypass -File scripts/package-win.ps1 -OpenClawPkg openclaw

# Windows - Chinese edition (default)
powershell -ExecutionPolicy Bypass -File scripts/package-win.ps1

# macOS / Linux - Official edition
OPENCLAW_PKG=openclaw bash scripts/package-unix.sh

# macOS / Linux - Chinese edition (default)
bash scripts/package-unix.sh
```

---

## Updating

### Automatic Updates
ClawPanel automatically detects new versions and prompts for updates.

### Manual Update
Re-run the install script to upgrade in-place:

```bash
# macOS / Linux
curl -fsSL https://dl.qrj.ai/openclaw/install.sh | EDITION=en bash

# Windows — re-download and run the installer
```

---

## FAQ

### Q: What's the difference between Official and Chinese editions?
A: They are functionally identical. The Chinese edition (`@qingchencloud/openclaw-zh`) has localized UI text and prompts. The Official edition (`openclaw`) is the same as the upstream npm package.

### Q: How is this different from `npm install -g openclaw`?
A: Same result, but you don't need Node.js, npm, or an internet connection for dependencies. Everything is pre-compiled and bundled.

### Q: Does it support Raspberry Pi?
A: Yes! Download the `linux-arm64` version. Supports Raspberry Pi 4/5 and other ARM64 devices.

### Q: Why is the package so large (200-300MB)?
A: It includes the complete Node.js runtime and all pre-compiled dependencies (sharp, SQLite, etc.). This is the trade-off for zero-dependency installation — but it's much faster than spending 10-30 minutes on `npm install`.

### Q: Can it coexist with an npm-installed OpenClaw?
A: Yes, but we recommend keeping only one. If both are in PATH, the system will use whichever appears first.

---

## License

[AGPL-3.0](LICENSE) + Commercial License

- Personal / Student / Non-commercial: Free ✅
- Commercial use: Must comply with AGPL or purchase a commercial license

---

## Related Projects

- [OpenClaw](https://github.com/openclaw/openclaw) — AI Agent Engine (upstream)
- [OpenClaw Chinese](https://github.com/1186258278/OpenClawChineseTranslation) — Chinese localization source
- [ClawPanel](https://github.com/qingchencloud/clawpanel) — GUI Management Panel
- [openclaw-docker](https://github.com/qingchencloud/openclaw-docker) — Docker deployment
- [QingChenCloud](https://gpt.qt.cool) — AI API service
