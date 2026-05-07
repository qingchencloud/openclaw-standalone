#!/bin/bash
# OpenClaw Standalone - macOS/Linux Packaging Script
# Usage: bash scripts/package-unix.sh
# Requires: Node.js 22+ installed on the build machine

set -euo pipefail

OPENCLAW_PKG="${OPENCLAW_PKG:-@qingchencloud/openclaw-zh}"
OUTPUT_DIR="${OUTPUT_DIR:-output}"
SCRIPT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"


cd "$SCRIPT_ROOT"

# --- Detect platform ---
OS="$(uname -s)"
ARCH="$(uname -m)"

case "$OS" in
    Darwin) PLATFORM_OS="mac" ;;
    Linux)  PLATFORM_OS="linux" ;;
    *)      echo "Unsupported OS: $OS"; exit 1 ;;
esac

case "$ARCH" in
    x86_64|amd64) PLATFORM_ARCH="x64" ;;
    aarch64|arm64) PLATFORM_ARCH="arm64" ;;
    armv7l)        PLATFORM_ARCH="armv7l" ;;
    *)             echo "Unsupported arch: $ARCH"; exit 1 ;;
esac

PLATFORM="${PLATFORM_OS}-${PLATFORM_ARCH}"
BUILD_DIR="build/${PLATFORM}"

echo "=== OpenClaw Standalone Packager ==="
echo "Platform: $PLATFORM"
echo "Package:  $OPENCLAW_PKG"
echo ""

# --- 1. Validate Node.js ---
echo "=== Step 1: Validating Node.js ==="
NODE_VERSION="$(node --version 2>/dev/null || true)"
if [ -z "$NODE_VERSION" ]; then
    echo "ERROR: Node.js not found. Please install Node.js 22+ first."
    exit 1
fi
NODE_PATH="$(which node)"
echo "Node.js version: $NODE_VERSION"
echo "Node.js binary:  $NODE_PATH"

# --- 2. Clean & create build directory ---
echo ""
echo "=== Step 2: Preparing build directory ==="
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# --- 3. Install OpenClaw ---
echo ""
echo "=== Step 3: Installing $OPENCLAW_PKG ==="
pushd "$BUILD_DIR" > /dev/null

# Create minimal package.json
echo '{ "name": "openclaw-standalone-build", "private": true }' > package.json

# Install with optional deps, use China mirror
npm install "$OPENCLAW_PKG" \
    --registry https://registry.npmmirror.com \
    --include=optional \
    2>&1 | tail -5

popd > /dev/null

# --- 3b. Patch: ensure changelog.js has required exports (upstream bug in @mariozechner/pi-coding-agent) ---
# NOTE: As of pi-coding-agent 0.73.0+ this file ships with valid exports.
# We keep this as a safety net for older transitive versions.
CHANGELOG_STUB="$BUILD_DIR/node_modules/@mariozechner/pi-coding-agent/dist/utils/changelog.js"
NEEDS_PATCH=false
if [ -d "$(dirname "$CHANGELOG_STUB")" ]; then
    if [ ! -f "$CHANGELOG_STUB" ]; then
        NEEDS_PATCH=true
    elif ! grep -q 'export function getChangelogPath' "$CHANGELOG_STUB" 2>/dev/null; then
        NEEDS_PATCH=true
    fi
fi
if [ "$NEEDS_PATCH" = true ]; then
    echo "Patching: creating/replacing changelog.js stub"
    mkdir -p "$(dirname "$CHANGELOG_STUB")"
    cat > "$CHANGELOG_STUB" <<'EOF'
export function getChangelogPath() { return null }
export function parseChangelog() { return [] }
export function getNewEntries() { return [] }
EOF
else
    echo "changelog.js exports OK (no patch needed)"
fi

# --- 4. Copy Node.js binary ---
echo ""
echo "=== Step 4: Copying Node.js runtime ==="
cp "$NODE_PATH" "$BUILD_DIR/node"
chmod +x "$BUILD_DIR/node"
echo "Copied node binary to build directory"

# --- 5. Copy shim ---
echo ""
echo "=== Step 5: Creating CLI shim ==="
cp "shims/openclaw" "$BUILD_DIR/openclaw"
chmod +x "$BUILD_DIR/openclaw"

# --- 6. Get version info ---
echo ""
echo "=== Step 6: Reading version info ==="
PKG_JSON="$BUILD_DIR/node_modules/@qingchencloud/openclaw-zh/package.json"
if [ ! -f "$PKG_JSON" ]; then
    PKG_JSON="$BUILD_DIR/node_modules/openclaw/package.json"
fi
if [ ! -f "$PKG_JSON" ]; then
    echo "ERROR: Cannot find package.json for version detection."
    exit 1
fi
VERSION="$(node -e "console.log(require('$PKG_JSON').version)")"
echo "OpenClaw version: $VERSION"

cat > "$BUILD_DIR/VERSION" <<EOF
openclaw_version=$VERSION
node_version=$NODE_VERSION
platform=$PLATFORM
build_date=$(date -u '+%Y-%m-%d %H:%M:%S UTC')
EOF

# --- 7. Clean up unnecessary files ---
echo ""
echo "=== Step 7: Cleaning up unnecessary files ==="
BEFORE_SIZE=$(du -sm "$BUILD_DIR/node_modules" | cut -f1)

# Remove unnecessary files
# IMPORTANT: Exclude the openclaw package itself from cleanup.
# Its dist/ contains Vite/Rollup chunks with hash names that match cleanup patterns.
find "$BUILD_DIR/node_modules" -type f \( \
    -name "*.ts" -not -name "*.d.ts" -o \
    -name "*.map" -o \
    -name "*.md" -o \
    -name "CHANGELOG*" -o \
    -name "HISTORY*" -o \
    -name "AUTHORS*" -o \
    -name "CONTRIBUTORS*" -o \
    -name ".npmignore" -o \
    -name ".eslintrc*" -o \
    -name ".prettierrc*" -o \
    -name "tsconfig*.json" -o \
    -name "Makefile" -o \
    -name ".editorconfig" -o \
    -name ".travis.yml" \
\) ! -name "*.js" ! -name "*.mjs" ! -name "*.cjs" \
   ! -path "*/openclaw/*" \
   ! -path "*/@qingchencloud/openclaw-zh/*" \
   -delete 2>/dev/null || true

# Remove unnecessary directories (but not inside the openclaw package)
find "$BUILD_DIR/node_modules" -type d \( \
    -name "test" -o \
    -name "tests" -o \
    -name "__tests__" -o \
    -name "spec" -o \
    -name "specs" -o \
    -name "example" -o \
    -name "examples" -o \
    -name ".github" -o \
    -name ".circleci" \
\) ! -path "*/openclaw/*" \
   ! -path "*/@qingchencloud/openclaw-zh/*" \
   -exec rm -rf {} + 2>/dev/null || true

AFTER_SIZE=$(du -sm "$BUILD_DIR/node_modules" | cut -f1)
echo "Cleaned: ${BEFORE_SIZE}MB -> ${AFTER_SIZE}MB (saved $((BEFORE_SIZE - AFTER_SIZE))MB)"

# Remove build package.json
rm -f "$BUILD_DIR/package.json" "$BUILD_DIR/package-lock.json"

# --- 8. Create tar.gz archive ---
echo ""
echo "=== Step 8: Creating tar.gz archive ==="
mkdir -p "$OUTPUT_DIR"
ARCHIVE_NAME="openclaw-${VERSION}-${PLATFORM}.tar.gz"
ARCHIVE_PATH="$OUTPUT_DIR/$ARCHIVE_NAME"

# Rename to 'openclaw' for clean extraction
mv "$BUILD_DIR" "build/openclaw"
tar -czf "$ARCHIVE_PATH" -C "build" "openclaw"
mv "build/openclaw" "$BUILD_DIR"

ARCHIVE_SIZE=$(du -sm "$ARCHIVE_PATH" | cut -f1)
echo "Created: $ARCHIVE_PATH (${ARCHIVE_SIZE}MB)"

# --- 9. Generate checksum ---
echo ""
echo "=== Step 9: Generating checksum ==="
if command -v sha256sum &>/dev/null; then
    sha256sum "$ARCHIVE_PATH" > "$ARCHIVE_PATH.sha256"
elif command -v shasum &>/dev/null; then
    shasum -a 256 "$ARCHIVE_PATH" > "$ARCHIVE_PATH.sha256"
fi
echo "Checksum: $(cat "$ARCHIVE_PATH.sha256")"

# --- Summary ---
echo ""
echo "=== Build Complete ==="
echo "Version:  $VERSION"
echo "Platform: $PLATFORM"
echo "Output:   $OUTPUT_DIR/"
ls -lh "$OUTPUT_DIR/"
