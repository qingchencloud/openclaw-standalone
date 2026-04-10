@echo off
chcp 65001 >nul 2>&1
setlocal enabledelayedexpansion

:: OpenClaw 一键安装脚本 (Windows)
:: Usage: 直接双击运行，或在 PowerShell 中执行:
::   irm https://dl.qrj.ai/openclaw/install.cmd | cmd

echo.
echo ╔══════════════════════════════════════╗
echo ║     OpenClaw 一键安装 by 晴辰云     ║
echo ╚══════════════════════════════════════╝
echo.

:: EDITION 环境变量: zh=汉化版(默认), en=官方原版
if "%EDITION%"=="" set "EDITION=zh"
set "INSTALL_DIR=%LOCALAPPDATA%\OpenClaw"
set "R2_BASE=https://dl.qrj.ai/openclaw-standalone"
set "PLATFORM=win-x64"

if "%EDITION%"=="en" (
    set "ARCHIVE_PREFIX=openclaw"
    echo [INFO] 版本: 官方原版 ^(en^)
) else (
    set "EDITION=zh"
    set "ARCHIVE_PREFIX=openclaw-zh"
    echo [INFO] 版本: 汉化版 ^(zh^)
)

:: --- Get latest version ---
echo [INFO] 获取最新版本...
:: 新格式: editions.<EDITION>.version；旧格式兼容: .version
for /f "delims=" %%v in ('powershell -NoProfile -Command "$m = Invoke-RestMethod -Uri '%R2_BASE%/latest.json' -TimeoutSec 5; $ed = $m.editions.'%EDITION%'; if ($ed.version) { $ed.version } elseif ($m.version) { $m.version }" 2^>nul') do set "VERSION=%%v"

:: GitHub API fallback（tag 基于汉化版版本号）
if "%VERSION%"=="" (
    echo [WARN] R2 获取失败，尝试 GitHub...
    for /f "delims=" %%v in ('powershell -NoProfile -Command "$tag = (Invoke-RestMethod -Uri 'https://api.github.com/repos/qingchencloud/openclaw-standalone/releases/latest' -TimeoutSec 10).tag_name -replace 'v',''; if ('%EDITION%' -eq 'en') { $tag -replace '-zh\.\d+$','' } else { $tag }" 2^>nul') do set "VERSION=%%v"
)

if "%VERSION%"=="" (
    echo [ERROR] 无法获取最新版本号。请检查网络连接。
    echo         或手动下载: https://github.com/qingchencloud/openclaw-standalone/releases
    pause
    exit /b 1
)

echo [INFO] 最新版本: %VERSION%

:: --- Download ---
set "ARCHIVE=%ARCHIVE_PREFIX%-%VERSION%-win-x64.zip"
set "DOWNLOAD_URL=%R2_BASE%/%EDITION%/%VERSION%/%ARCHIVE%"
set "TMP_FILE=%TEMP%\%ARCHIVE%"

echo [INFO] 下载安装包...
powershell -NoProfile -Command "try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; $ProgressPreference = 'SilentlyContinue'; Invoke-WebRequest -Uri '%DOWNLOAD_URL%' -OutFile '%TMP_FILE%' -UseBasicParsing } catch { exit 1 }"

if errorlevel 1 (
    echo [WARN] R2 下载失败，尝试 GitHub...
    :: GitHub release tag 统一用汉化版版本号，先获取 tag
    for /f "delims=" %%t in ('powershell -NoProfile -Command "(Invoke-RestMethod -Uri 'https://api.github.com/repos/qingchencloud/openclaw-standalone/releases/latest' -TimeoutSec 10).tag_name" 2^>nul') do set "GH_TAG=%%t"
    if "!GH_TAG!"=="" set "GH_TAG=v%VERSION%"
    set "DOWNLOAD_URL=https://github.com/qingchencloud/openclaw-standalone/releases/download/!GH_TAG!/%ARCHIVE%"
    powershell -NoProfile -Command "try { $ProgressPreference = 'SilentlyContinue'; Invoke-WebRequest -Uri '!DOWNLOAD_URL!' -OutFile '%TMP_FILE%' -UseBasicParsing } catch { exit 1 }"
)

if errorlevel 1 (
    echo [ERROR] 下载失败。请检查网络连接。
    pause
    exit /b 1
)

echo [OK] 下载完成

:: --- Extract ---
echo [INFO] 解压到 %INSTALL_DIR% ...
if exist "%INSTALL_DIR%" rmdir /s /q "%INSTALL_DIR%"
mkdir "%INSTALL_DIR%" 2>nul

powershell -NoProfile -Command "Expand-Archive -Path '%TMP_FILE%' -DestinationPath '%INSTALL_DIR%' -Force"

:: Handle nested 'openclaw' directory from archive
if exist "%INSTALL_DIR%\openclaw\node.exe" (
    powershell -NoProfile -Command "Get-ChildItem '%INSTALL_DIR%\openclaw\*' | Move-Item -Destination '%INSTALL_DIR%' -Force"
    rmdir /s /q "%INSTALL_DIR%\openclaw" 2>nul
)

del "%TMP_FILE%" 2>nul
echo [OK] 解压完成

:: --- Verify ---
if not exist "%INSTALL_DIR%\openclaw.cmd" (
    echo [ERROR] 解压后未找到 openclaw.cmd
    pause
    exit /b 1
)

:: --- Add to PATH ---
echo [INFO] 配置环境变量...
powershell -NoProfile -Command ^
    "$userPath = [Environment]::GetEnvironmentVariable('Path', 'User'); " ^
    "if ($userPath -notlike '*%INSTALL_DIR%*') { " ^
    "  [Environment]::SetEnvironmentVariable('Path', $userPath + ';%INSTALL_DIR%', 'User'); " ^
    "  Write-Host '[OK] 已添加到 PATH' " ^
    "} else { " ^
    "  Write-Host '[INFO] PATH 已包含安装目录' " ^
    "}"

:: Add to current session PATH too
set "PATH=%INSTALL_DIR%;%PATH%"

:: --- Verify version ---
echo.
"%INSTALL_DIR%\openclaw.cmd" --version 2>nul

:: --- Done ---
echo.
echo ╔══════════════════════════════════════╗
echo ║       ✅ OpenClaw 安装成功！         ║
echo ╚══════════════════════════════════════╝
echo.
echo   安装目录: %INSTALL_DIR%
echo.
echo   请重新打开终端（PowerShell / CMD）使 PATH 生效，然后：
echo     openclaw --help        # 查看帮助
echo     openclaw setup         # 初始化配置
echo     openclaw gateway       # 启动 Gateway
echo.
echo   图形管理面板: https://github.com/qingchencloud/clawpanel
echo   AI 接口服务:  https://gpt.qt.cool
echo.
pause
