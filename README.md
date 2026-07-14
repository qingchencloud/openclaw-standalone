# OpenClaw Standalone

**零依赖安装包** — 无需 Node.js，无需 npm，下载即用！

由 [晴辰云 (QingChenCloud)](https://gpt.qt.cool) 构建和维护。

[![Build](https://github.com/qingchencloud/openclaw-standalone/actions/workflows/build.yml/badge.svg)](https://github.com/qingchencloud/openclaw-standalone/actions/workflows/build.yml)
[![License: AGPL-3.0](https://img.shields.io/badge/License-AGPL--3.0-blue.svg)](LICENSE)

> **[English version →](README.en.md)**

---

## 为什么需要这个项目？

[OpenClaw](https://github.com/openclaw/openclaw) 是一个强大的 AI 智能体引擎，但官方安装方式依赖 `npm install -g`，存在以下痛点：

- 🐢 **国内网络慢**：npm 默认从境外 registry 下载，大量依赖导致安装耗时 10-30 分钟
- 🔧 **环境要求高**：需要预装 Node.js 22+、npm、Git，还可能遇到原生模块编译失败
- 🤯 **新手不友好**：各种权限、PATH、网络报错让非技术用户望而却步

**OpenClaw Standalone** 解决了这一切：

- ✅ **零依赖**：内置 Node.js 运行时和所有预编译依赖
- ✅ **秒级安装**：下载 → 解压 → 就能用
- ✅ **全平台**：Windows / macOS / Linux / 树莓派
- ✅ **Windows 引导安装**：专业的 .exe 安装向导，跟装普通软件一样简单
- ✅ **双版本**：同时提供官方原版和汉化版

---

## 版本选择

本项目提供 **两个版本** 的预编译安装包，从同一个仓库同一个 CI 流水线构建：

| 版本 | 包名 | 文件前缀 | 说明 |
|------|------|---------|------|
| **汉化版** | `@qingchencloud/openclaw-zh` | `openclaw-zh-*` | 中文界面和提示，推荐国内用户 |
| **官方原版** | `openclaw` | `openclaw-*` | 英文原版，与官方 npm 包一致 |

两个版本功能完全一致，区别仅在于界面语言和提示文本。

---

## 安装方法

### Windows（推荐：安装向导）

1. 从 [Releases](https://github.com/qingchencloud/openclaw-standalone/releases) 下载对应版本的安装包：
   - 汉化版：`openclaw-zh-*-win-x64-setup.exe`
   - 原版：`openclaw-*-win-x64-setup.exe`
2. 双击运行安装向导
3. 打开终端，输入 `openclaw` 即可使用

> 也可以下载 `.zip` 绿色免安装版，解压后手动添加目录到 PATH。

### macOS / Linux（一键安装）

```bash
# 汉化版（默认）
curl -fsSL https://dl.qrj.ai/openclaw/install.sh | bash

# 官方原版
curl -fsSL https://dl.qrj.ai/openclaw/install.sh | EDITION=en bash
```

支持的平台：
- macOS ARM64 (Apple Silicon / M1-M4)
- macOS x64 (Intel)
- Linux x64
- Linux ARM64 (树莓派 4/5、ARM 服务器)

### 手动安装

1. 从 [Releases](https://github.com/qingchencloud/openclaw-standalone/releases) 下载对应平台和版本的压缩包
2. 解压到任意目录
3. 将该目录添加到系统 PATH
4. 打开终端，输入 `openclaw --version` 验证

---

## 下载一览

### 汉化版 (`openclaw-zh-*`)

| 平台 | 架构 | 文件类型 | 说明 |
|------|------|---------|------|
| Windows | x64 | `.exe` 安装包 | 引导式安装，自动配置 PATH |
| Windows | x64 | `.zip` | 绿色免安装，解压即用 |
| macOS | ARM64 (Apple Silicon) | `.tar.gz` | 解压即用 |
| macOS | x64 (Intel) | `.tar.gz` | 解压即用 |
| Linux | x64 | `.tar.gz` | 解压即用 |
| Linux | ARM64 | `.tar.gz` | 树莓派、ARM 服务器 |

### 官方原版 (`openclaw-*`)

| 平台 | 架构 | 文件类型 | 说明 |
|------|------|---------|------|
| Windows | x64 | `.exe` installer | Guided setup |
| Windows | x64 | `.zip` | Portable |
| macOS | ARM64 (Apple Silicon) | `.tar.gz` | Extract & run |
| macOS | x64 (Intel) | `.tar.gz` | Extract & run |
| Linux | x64 | `.tar.gz` | Extract & run |
| Linux | ARM64 | `.tar.gz` | Raspberry Pi, ARM servers |

---

## 快速开始

```bash
# 查看帮助
openclaw --help

# 初始化配置（首次使用）
openclaw setup

# 启动 AI Gateway
openclaw gateway

# 查看状态
openclaw status
```

### 搭配图形管理面板

推荐安装 [ClawPanel](https://github.com/qingchencloud/clawpanel) 图形化管理面板，提供：
- 可视化模型配置
- 智能体管理
- 消息渠道（飞书、钉钉、QQ 等）
- Docker 军团调度
- 定时任务、技能市场等

### 使用晴辰云 AI 接口

[晴辰云](https://gpt.qt.cool) 提供兼容 OpenAI 的 API 接口：
- 每天签到送免费额度
- 支持 GPT-5 全系列模型
- 端点：`https://gpt.qt.cool/v1`

---

## 构建原理

本项目的核心思想：**在 CI 的各平台 runner 上预编译所有原生模块，打包 Node.js 运行时 + 完整 node_modules 成自包含发行包。**

```
GitHub Actions CI Matrix (2 editions × 4 platforms = 8 parallel builds)

汉化版 (zh):                           官方原版 (en):
├── windows-latest → zip + .exe         ├── windows-latest → zip + .exe
├── macos-15       → tar.gz             ├── macos-15       → tar.gz
├── ubuntu-latest  → tar.gz             ├── ubuntu-latest  → tar.gz
└── ubuntu-arm64   → tar.gz             └── ubuntu-arm64   → tar.gz
```

每个平台的产出包含：
- `node` / `node.exe` — Node.js 运行时
- `openclaw` / `openclaw.cmd` — CLI 入口脚本
- `node_modules/` — 所有依赖（含预编译的原生模块）
- `VERSION` — 版本和版本源信息

### 本地构建

```bash
# Windows - 汉化版（默认）
powershell -ExecutionPolicy Bypass -File scripts/package-win.ps1

# Windows - 官方原版
powershell -ExecutionPolicy Bypass -File scripts/package-win.ps1 -OpenClawPkg openclaw

# macOS / Linux - 汉化版（默认）
bash scripts/package-unix.sh

# macOS / Linux - 官方原版
OPENCLAW_PKG=openclaw bash scripts/package-unix.sh
```

---

## 更新

### 自动更新
ClawPanel 会自动检测新版本并提示更新。

### 手动更新
重新运行安装脚本即可覆盖安装：

```bash
# macOS / Linux
curl -fsSL https://dl.qrj.ai/openclaw/install.sh | bash

# Windows
# 重新下载安装包运行即可
```

---

## 常见问题

### Q: 汉化版和原版有什么区别？
A: 功能完全一致。区别在于界面语言和提示文本——汉化版是中文，原版是英文。汉化版基于 [`@qingchencloud/openclaw-zh`](https://github.com/1186258278/OpenClawChineseTranslation)，原版基于官方 [`openclaw`](https://github.com/openclaw/openclaw) npm 包。

### Q: 这个跟 `npm install -g openclaw` 有什么区别？
A: 效果完全一样，但不需要预装 Node.js 和 npm，也不需要网络下载依赖。所有东西都预编译打包好了。

### Q: 支持树莓派吗？
A: 支持！下载 `linux-arm64` 版本即可。支持树莓派 4/5 及其他 ARM64 设备。

### Q: 安装包为什么这么大（200-300MB）？
A: 因为包含了完整的 Node.js 运行时和所有预编译的依赖（包括图片处理库 sharp、SQLite 等原生模块）。这是"零依赖"的代价，但相比 npm 安装耗时 30 分钟，一次下载几分钟更划算。

### Q: 能跟 npm 安装的 OpenClaw 共存吗？
A: 可以，但建议只保留一个。如果两个都在 PATH 中，系统会使用 PATH 中靠前的那个。

---

## 许可证

[AGPL-3.0](LICENSE) + 商业授权

- 个人/学生/非商业：完全自由 ✅
- 企业商用：需遵守 AGPL 或购买商业授权

---

## 相关项目

- [OpenClaw](https://github.com/openclaw/openclaw) — AI 智能体引擎（上游官方）
- [OpenClaw 汉化版](https://github.com/1186258278/OpenClawChineseTranslation) — 汉化版源码
- [ClawPanel](https://github.com/qingchencloud/clawpanel) — 图形化管理面板
- [openclaw-docker](https://github.com/qingchencloud/openclaw-docker) — Docker 部署方案
- [晴辰云](https://gpt.qt.cool) — AI 接口服务
