# OpenClaw Standalone - Windows x64 Packaging Script
# Usage: powershell -ExecutionPolicy Bypass -File scripts/package-win.ps1
# Requires: Node.js 22+ installed on the build machine

param(
    [string]$OpenClawPkg = "@qingchencloud/openclaw-zh",
    [string]$OutputDir = "output",
    [string]$BuildDir = "build\win-x64",
    [switch]$SkipInstaller
)

$ErrorActionPreference = "Stop"

$SCRIPT_ROOT = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $SCRIPT_ROOT


# --- 1. Validate Node.js ---
Write-Host "=== Step 1: Validating Node.js ===" -ForegroundColor Cyan
$nodeVersion = & node --version 2>$null
if (-not $nodeVersion) {
    Write-Error "Node.js not found. Please install Node.js 22+ first."
    exit 1
}
Write-Host "Node.js version: $nodeVersion"
$nodePath = (Get-Command node).Source
Write-Host "Node.js binary: $nodePath"

# --- 2. Clean & create build directory ---
Write-Host "`n=== Step 2: Preparing build directory ===" -ForegroundColor Cyan
if (Test-Path $BuildDir) {
    Remove-Item -Recurse -Force $BuildDir
}
New-Item -ItemType Directory -Force -Path $BuildDir | Out-Null

# --- 3. Install OpenClaw into build directory ---
Write-Host "`n=== Step 3: Installing $OpenClawPkg ===" -ForegroundColor Cyan
Push-Location $BuildDir

# Create a minimal package.json to allow local install
@'
{ "name": "openclaw-standalone-build", "private": true }
'@ | Set-Content -Path "package.json" -Encoding UTF8

# Install with all optional dependencies, use China mirror for faster CI
Write-Host "Running: npm install $OpenClawPkg --registry https://registry.npmmirror.com --include=optional"
& npm.cmd install $OpenClawPkg --registry https://registry.npmmirror.com --include=optional
if ($LASTEXITCODE -ne 0) {
    Write-Error "npm install failed with exit code $LASTEXITCODE"
    exit 1
}
Pop-Location

# --- 3b. Patch: ensure changelog.js has required exports (upstream bug in @mariozechner/pi-coding-agent) ---
# NOTE: As of pi-coding-agent 0.73.0+ this file ships with valid exports.
# We keep this as a safety net for older transitive versions.
$changelogStub = "$BuildDir\node_modules\@mariozechner\pi-coding-agent\dist\utils\changelog.js"
$needsPatch = $false
if (Test-Path (Split-Path $changelogStub)) {
    if (-not (Test-Path $changelogStub)) {
        $needsPatch = $true
    } else {
        $existingContent = Get-Content $changelogStub -Raw -ErrorAction SilentlyContinue
        if ($existingContent -notmatch 'export\s+function\s+getChangelogPath') {
            $needsPatch = $true
        }
    }
}
if ($needsPatch) {
    Write-Host "Patching: creating/replacing changelog.js stub" -ForegroundColor Yellow
    $stubDir = Split-Path $changelogStub
    if (-not (Test-Path $stubDir)) { New-Item -ItemType Directory -Force -Path $stubDir | Out-Null }
    @'
export function getChangelogPath() { return null }
export function parseChangelog() { return [] }
export function getNewEntries() { return [] }
'@ | Set-Content -Path $changelogStub -Encoding UTF8
} else {
    Write-Host "changelog.js exports OK (no patch needed)"
}

# --- 4. Copy Node.js binary ---
Write-Host "`n=== Step 4: Copying Node.js runtime ===" -ForegroundColor Cyan
Copy-Item $nodePath "$BuildDir\node.exe"
Write-Host "Copied node.exe to build directory"

# --- 5. Copy shim ---
Write-Host "`n=== Step 5: Creating CLI shim ===" -ForegroundColor Cyan
Copy-Item "shims\openclaw.cmd" "$BuildDir\openclaw.cmd"

# --- 6. Get version info ---
Write-Host "`n=== Step 6: Reading version info ===" -ForegroundColor Cyan
$pkgJsonPath = "$BuildDir\node_modules\@qingchencloud\openclaw-zh\package.json"
if (-not (Test-Path $pkgJsonPath)) {
    $pkgJsonPath = "$BuildDir\node_modules\openclaw\package.json"
}
if (-not (Test-Path $pkgJsonPath)) {
    Write-Error "Cannot find package.json for version detection. Checked @qingchencloud/openclaw-zh and openclaw."
    exit 1
}
$pkgJson = Get-Content $pkgJsonPath -Raw | ConvertFrom-Json
$version = $pkgJson.version
Write-Host "OpenClaw version: $version"

# Write VERSION file
@"
openclaw_version=$version
node_version=$nodeVersion
platform=win-x64
build_date=$(Get-Date -Format "yyyy-MM-dd HH:mm:ss UTC" -AsUTC)
"@ | Set-Content -Path "$BuildDir\VERSION" -Encoding UTF8

# --- 7. Remove unnecessary files to reduce size ---
Write-Host "`n=== Step 7: Cleaning up unnecessary files ===" -ForegroundColor Cyan
$cleanPatterns = @(
    "*.md", "*.ts", "*.map", "*.d.ts",
    "CHANGELOG*", "HISTORY*", "AUTHORS*", "CONTRIBUTORS*",
    ".npmignore", ".eslintrc*", ".prettierrc*", "tsconfig*.json",
    "Makefile", "Gruntfile*", "Gulpfile*",
    ".travis.yml", ".github", ".circleci",
    "test", "tests", "__tests__", "spec", "specs",
    "example", "examples", "doc", "docs",
    ".editorconfig", ".jshintrc", ".flowconfig"
)
# Protect the main app package from cleanup - its dist/ contains Vite chunks with hash names
function Test-Protected($path) {
    return ($path -like '*\openclaw\*' -or $path -like '*\@qingchencloud\openclaw-zh\*')
}
$savedMB = 0
foreach ($pattern in $cleanPatterns) {
    $items = Get-ChildItem -Path "$BuildDir\node_modules" -Recurse -Filter $pattern -ErrorAction SilentlyContinue |
        Where-Object { $_.Extension -notin @('.js', '.mjs', '.cjs') -and -not (Test-Protected $_.FullName) }
    foreach ($item in $items) {
        $savedMB += $item.Length / 1MB
        Remove-Item -Recurse -Force $item.FullName -ErrorAction SilentlyContinue
    }
}
Write-Host ("Cleaned up ~{0:N1} MB of unnecessary files" -f $savedMB)

# Remove build package.json (not needed in final package)
Remove-Item "$BuildDir\package.json" -Force -ErrorAction SilentlyContinue
Remove-Item "$BuildDir\package-lock.json" -Force -ErrorAction SilentlyContinue
# (changelog.js patch verification handled in step 3b)

# --- 8. Create zip archive ---
Write-Host "`n=== Step 8: Creating zip archive ===" -ForegroundColor Cyan
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
$zipName = "openclaw-$version-win-x64.zip"
$zipPath = Join-Path $OutputDir $zipName

if (Test-Path $zipPath) { Remove-Item $zipPath -Force }

# Rename build dir to 'openclaw' for clean extraction
$finalDir = "build\openclaw"
if (Test-Path $finalDir) { Remove-Item -Recurse -Force $finalDir }
Rename-Item $BuildDir "openclaw"
Compress-Archive -Path $finalDir -DestinationPath $zipPath -CompressionLevel Optimal
# Rename back
Rename-Item $finalDir "win-x64"

$zipSize = (Get-Item $zipPath).Length / 1MB
Write-Host ("Created: $zipPath ({0:N1} MB)" -f $zipSize) -ForegroundColor Green

# --- 9. Build Inno Setup installer (optional) ---
if (-not $SkipInstaller) {
    Write-Host "`n=== Step 9: Building Inno Setup installer ===" -ForegroundColor Cyan
    $iscc = Get-Command "ISCC" -ErrorAction SilentlyContinue
    if (-not $iscc) {
        # Try common Inno Setup paths
        $issLocations = @(
            "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
            "$env:ProgramFiles\Inno Setup 6\ISCC.exe",
            "${env:ProgramFiles(x86)}\Inno Setup 5\ISCC.exe"
        )
        foreach ($loc in $issLocations) {
            if (Test-Path $loc) {
                $iscc = @{ Source = $loc }
                break
            }
        }
    }

    if ($iscc) {
        $issScript = "installer\setup.iss"
        & $iscc.Source "/DAppVersion=$version" "/DSourceDir=$SCRIPT_ROOT\build\win-x64" "/DOutputDir=$SCRIPT_ROOT\$OutputDir" $issScript
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Installer created successfully!" -ForegroundColor Green
        } else {
            Write-Warning "Inno Setup compilation failed (exit code: $LASTEXITCODE). Zip archive is still available."
        }
    } else {
        Write-Warning "Inno Setup not found. Skipping installer creation. Zip archive is still available."
        Write-Host "Install Inno Setup from: https://jrsoftware.org/isdl.php"
    }
}

# --- Summary ---
Write-Host "`n=== Build Complete ===" -ForegroundColor Green
Write-Host "Version:  $version"
Write-Host "Platform: win-x64"
Write-Host "Output:   $OutputDir\"
Get-ChildItem $OutputDir | ForEach-Object {
    Write-Host ("  {0} ({1:N1} MB)" -f $_.Name, ($_.Length / 1MB))
}
