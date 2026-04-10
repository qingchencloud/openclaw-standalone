#!/bin/bash
# OpenClaw 一键安装脚本 (macOS / Linux)
# Usage: curl -fsSL https://dl.qrj.ai/openclaw/install.sh | bash
# Or:    curl -fsSL https://raw.githubusercontent.com/qingchencloud/openclaw-standalone/main/install.sh | bash

set -euo pipefail

# --- Configuration ---
EDITION="${EDITION:-zh}"  # zh=汉化版, en=官方原版
INSTALL_DIR="${OPENCLAW_HOME:-$HOME/.openclaw-bin}"
R2_BASE="https://dl.qrj.ai/openclaw-standalone"
GITHUB_BASE="https://github.com/qingchencloud/openclaw-standalone/releases/download"

if [ "$EDITION" = "en" ]; then
    ARCHIVE_PREFIX="openclaw"
    EDITION_LABEL="官方原版"
else
    EDITION="zh"
    ARCHIVE_PREFIX="openclaw-zh"
    EDITION_LABEL="汉化版"
fi

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${CYAN}[INFO]${NC} $*"; }
ok()    { echo -e "${GREEN}[OK]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

# --- Detect platform ---
detect_platform() {
    local os arch
    os="$(uname -s)"
    arch="$(uname -m)"

    case "$os" in
        Darwin) os="mac" ;;
        Linux)  os="linux" ;;
        *)      error "不支持的操作系统: $os" ;;
    esac

    case "$arch" in
        x86_64|amd64)  arch="x64" ;;
        aarch64|arm64) arch="arm64" ;;
        armv7l)        arch="armv7l" ;;
        *)             error "不支持的架构: $arch" ;;
    esac

    echo "${os}-${arch}"
}

# --- Get latest version ---
get_latest_version() {
    local version="" json=""
    # Try R2 first
    # 新格式: editions.<EDITION>.version；旧格式兼容: .version
    if command -v curl &>/dev/null; then
        json=$(curl -fsSL --connect-timeout 5 "$R2_BASE/latest.json" 2>/dev/null) || true
        if [ -n "$json" ]; then
            # 先尝试新格式 editions.<EDITION>.version
            version=$(echo "$json" | grep -o "\"$EDITION\"[^}]*\"version\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" | \
                grep -o '"version"[[:space:]]*:[[:space:]]*"[^"]*"' | \
                grep -o '"[^"]*"$' | tr -d '"') || true
            # 回退旧格式 .version（取第一个 version 字段）
            if [ -z "$version" ]; then
                version=$(echo "$json" | \
                    grep -o '"version"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | \
                    grep -o '"[^"]*"$' | tr -d '"') || true
            fi
        fi
    fi
    # Fallback: GitHub API（tag 基于汉化版版本号，两个版本文件都在同一个 release 下）
    if [ -z "$version" ]; then
        local tag_ver
        tag_ver=$(curl -fsSL --connect-timeout 5 \
            "https://api.github.com/repos/qingchencloud/openclaw-standalone/releases/latest" 2>/dev/null | \
            grep -o '"tag_name"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | \
            grep -o '"[^"]*"$' | tr -d '"v') || true
        if [ -n "$tag_ver" ]; then
            if [ "$EDITION" = "en" ]; then
                # 官方版版本号 = 去掉 -zh.N 后缀
                version=$(echo "$tag_ver" | sed 's/-zh\.[0-9]*$//')
            else
                version="$tag_ver"
            fi
        fi
    fi
    if [ -z "$version" ]; then
        error "无法获取最新版本号。请检查网络连接或手动下载安装。"
    fi
    echo "$version"
}

# --- Download with retry ---
download() {
    local url="$1" dest="$2"
    local max_retries=3 retry=0

    while [ $retry -lt $max_retries ]; do
        if curl -fSL --connect-timeout 10 --progress-bar -o "$dest" "$url" 2>&1; then
            return 0
        fi
        retry=$((retry + 1))
        warn "下载失败，正在重试 ($retry/$max_retries)..."
        sleep 2
    done
    return 1
}

# --- Main ---
main() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║     OpenClaw 一键安装 by 晴辰云     ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════╝${NC}"
    echo ""

    PLATFORM=$(detect_platform)
    info "检测到平台: $PLATFORM"
    info "版本: $EDITION_LABEL ($EDITION)"

    VERSION=$(get_latest_version)
    info "最新版本: $VERSION"

    ARCHIVE="${ARCHIVE_PREFIX}-${VERSION}-${PLATFORM}.tar.gz"
    DOWNLOAD_URL="${R2_BASE}/${EDITION}/${VERSION}/${ARCHIVE}"
    # GitHub release tag 统一用汉化版版本号，两个版本的文件都在同一个 release 下
    if [ "$EDITION" = "en" ]; then
        # 需要从 R2 或 GitHub API 获取汉化版版本号作为 tag
        GH_TAG_VER=$(curl -fsSL --connect-timeout 5 \
            "https://api.github.com/repos/qingchencloud/openclaw-standalone/releases/latest" 2>/dev/null | \
            grep -o '"tag_name"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | \
            grep -o '"[^"]*"$' | tr -d '"') || true
        GITHUB_URL="${GITHUB_BASE}/${GH_TAG_VER:-v${VERSION}}/${ARCHIVE}"
    else
        GITHUB_URL="${GITHUB_BASE}/v${VERSION}/${ARCHIVE}"
    fi
    TMP_DIR=$(mktemp -d)
    TMP_FILE="${TMP_DIR}/${ARCHIVE}"

    info "下载安装包..."
    if ! download "$DOWNLOAD_URL" "$TMP_FILE"; then
        warn "R2 下载失败，尝试 GitHub..."
        if ! download "$GITHUB_URL" "$TMP_FILE"; then
            rm -rf "$TMP_DIR"
            error "下载失败。请检查网络连接或手动下载：\n  $GITHUB_URL"
        fi
    fi
    ok "下载完成: $(du -h "$TMP_FILE" | cut -f1)"

    # Extract
    info "解压到 $INSTALL_DIR ..."
    rm -rf "$INSTALL_DIR"
    mkdir -p "$INSTALL_DIR"
    tar -xzf "$TMP_FILE" -C "$INSTALL_DIR" --strip-components=1
    rm -rf "$TMP_DIR"
    ok "解压完成"

    # Verify
    if [ ! -x "$INSTALL_DIR/openclaw" ]; then
        error "解压后未找到 openclaw 可执行文件"
    fi

    # Check version
    INSTALLED_VER=$("$INSTALL_DIR/openclaw" --version 2>/dev/null | tail -1 || echo "unknown")
    ok "已安装 OpenClaw: $INSTALLED_VER"

    # --- Add to PATH ---
    SHELL_NAME="$(basename "$SHELL" 2>/dev/null || echo "bash")"
    PATH_LINE="export PATH=\"$INSTALL_DIR:\$PATH\""
    ADDED_PATH=false

    case "$SHELL_NAME" in
        zsh)
            RC_FILE="$HOME/.zshrc"
            ;;
        bash)
            if [ -f "$HOME/.bash_profile" ]; then
                RC_FILE="$HOME/.bash_profile"
            else
                RC_FILE="$HOME/.bashrc"
            fi
            ;;
        fish)
            RC_FILE="$HOME/.config/fish/config.fish"
            PATH_LINE="set -gx PATH $INSTALL_DIR \$PATH"
            ;;
        *)
            RC_FILE="$HOME/.profile"
            ;;
    esac

    if [ -f "$RC_FILE" ] && grep -qF "$INSTALL_DIR" "$RC_FILE" 2>/dev/null; then
        info "PATH 已包含 $INSTALL_DIR"
    else
        echo "" >> "$RC_FILE"
        echo "# OpenClaw standalone" >> "$RC_FILE"
        echo "$PATH_LINE" >> "$RC_FILE"
        ADDED_PATH=true
        ok "已添加到 PATH ($RC_FILE)"
    fi

    # --- Done ---
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║       ✅ OpenClaw 安装成功！         ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════╝${NC}"
    echo ""
    echo "  安装目录: $INSTALL_DIR"
    echo "  版本:     $INSTALLED_VER"
    echo ""
    if [ "$ADDED_PATH" = true ]; then
        echo -e "  ${YELLOW}请执行以下命令使 PATH 生效：${NC}"
        echo "    source $RC_FILE"
        echo ""
    fi
    echo "  快速开始:"
    echo "    openclaw --help        # 查看帮助"
    echo "    openclaw setup         # 初始化配置"
    echo "    openclaw gateway       # 启动 Gateway"
    echo ""
    echo -e "  图形管理面板: ${CYAN}https://github.com/qingchencloud/clawpanel${NC}"
    echo -e "  AI 接口服务:  ${CYAN}https://gpt.qt.cool${NC}"
    echo ""
}

main "$@"
