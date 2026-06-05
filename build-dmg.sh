#!/bin/bash

# Ensure script halts on any errors
set -e

# ==========================================
# Terminal Color UI Config (中英双语日志输出)
# ==========================================
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

echo -e "${BLUE}=== Quick Cookies 本地一键打包 DMG 脚本 / One-click DMG Packaging Script ===${NC}"

# ==========================================
# 步骤 1: 验证是否在正确的项目根目录下运行
# Step 1: Verify current directory
# ==========================================
log_info "正在校验运行环境... / Validating run environment..."
if [ ! -f "QuickCookies.xcodeproj/project.pbxproj" ]; then
    log_error "未检测到 QuickCookies.xcodeproj 工程文件。 / QuickCookies.xcodeproj not found."
    log_error "请确保您在项目的根目录下执行此脚本。 / Please run this script in the project root directory. (e.g. ./build-dmg.sh)"
    exit 1
fi
log_success "当前所处工作区目录正确。 / Workspace directory verified."

# ==========================================
# 步骤 2: 验证打包工具链依赖
# Step 2: Verify toolchain dependencies
# ==========================================
log_info "正在检测本地打包工具依赖... / Checking local packaging dependencies..."

# Check xcodebuild and codesign
if ! command -v xcodebuild &> /dev/null || ! command -v codesign &> /dev/null; then
    log_error "未检测到 xcodebuild 或 codesign，请确保已安装 Xcode 命令行工具！ / xcodebuild or codesign not found. Xcode Command Line Tools required!"
    exit 1
fi

# Check create-dmg, install via Homebrew if missing
if ! command -v create-dmg &> /dev/null; then
    log_warning "未在您的系统中检测到 'create-dmg' 封装工具。 / 'create-dmg' tool not found on your system."
    if command -v brew &> /dev/null; then
        log_info "检测到已安装 Homebrew，正在为您静默安装 'create-dmg'... / Homebrew detected. Installing 'create-dmg'..."
        brew install create-dmg
        log_success "'create-dmg' 安装成功。 / 'create-dmg' installed successfully."
    else
        log_error "未安装 Homebrew，无法自动获取 'create-dmg'。 / Homebrew not installed. Cannot auto-install 'create-dmg'."
        log_error "请先在终端运行 'brew install create-dmg' 安装此依赖后重试！ / Please install 'create-dmg' manually and retry!"
        exit 1
    fi
fi
log_success "打包依赖工具链齐备。 / Packaging dependencies checked."

# ==========================================
# 步骤 3: 编译清理与 Release 构建
# Step 3: Cleanup and Release build
# ==========================================
BUILD_DIR="./buildClean"
log_info "正在清理旧的构建临时缓存... / Cleaning up old build caches..."
rm -rf "$BUILD_DIR"
rm -rf "./release_dist"
log_success "清理完成。 / Cleanup complete."

log_info "开始执行 Xcode Release 模式编译 (Unsigned)... / Building Xcode Release target (Unsigned)..."
xcodebuild -project QuickCookies.xcodeproj \
           -scheme QuickCookies \
           -configuration Release \
           -derivedDataPath "$BUILD_DIR" \
           CODE_SIGN_IDENTITY="" \
           CODE_SIGNING_REQUIRED=NO \
           CODE_SIGNING_ALLOWED=NO \
           clean build > /dev/null

log_success "编译 Release 产物成功。 / Build Release target succeeded."

# ==========================================
# 步骤 3.5: 拷贝 Highlightr 高亮依赖资源至主 App 资源根目录下
# Step 3.5: Copy Highlightr resources to main App resources root
# ==========================================
APP_PATH="$BUILD_DIR/Build/Products/Release/QuickCookies.app"
HIGHLIGHTR_BUNDLE_RESOURCES="$APP_PATH/Contents/Resources/Highlightr_Highlightr.bundle/Contents/Resources"

log_info "正在拷贝 Highlightr 代码高亮资源包至主 App 根目录... / Copying Highlightr resources to main App root..."
if [ -d "$HIGHLIGHTR_BUNDLE_RESOURCES" ]; then
    cp -R "$HIGHLIGHTR_BUNDLE_RESOURCES/"* "$APP_PATH/Contents/Resources/"
    log_success "Highlightr 依赖资源拷贝成功！ / Highlightr resources copied successfully."
else
    log_warning "未检测到 Highlightr.bundle，跳过拷贝。 / Highlightr.bundle not found. Skipping."
fi

# ==========================================
# 步骤 4: 强制进行 Ad-hoc 自签名
# Step 4: Force Ad-hoc signing (App & Ext)
# ==========================================
APP_PATH="$BUILD_DIR/Build/Products/Release/QuickCookies.app"
EXTENSION_PATH="$APP_PATH/Contents/PlugIns/QuickCookiesFinderSync.appex"

log_info "正在执行 Ad-hoc 覆盖自签名... / Applying Ad-hoc force signing..."

# 1. Sign Extension (Inside-out rule)
if [ -d "$EXTENSION_PATH" ]; then
    log_info "1. 正在对内置 Finder Sync 插件进行 Ad-hoc 签名... / 1. Signing Finder Sync app extension..."
    codesign --force --deep --sign - "$EXTENSION_PATH"
else
    log_warning "未发现 Finder Sync 扩展插件，跳过其签名。 / Finder Sync app extension not found. Skipping."
fi

# 2. Sign main App wrapper
log_info "2. 正在对主 App 进行 Ad-hoc 签名... / 2. Signing main App..."
codesign --force --deep --sign - "$APP_PATH"

# 3. Verify signature
log_info "正在校验 App 签名完整性状态... / Verifying code signature..."
codesign -vvv --deep --display "$APP_PATH"
log_success "Ad-hoc 签名覆盖完成。 / Ad-hoc signing completed."

# ==========================================
# 步骤 5: 打包生成 DMG 安装映像
# Step 5: Package DMG with clean source folder
# ==========================================
DIST_DIR="./release_dist"
mkdir -p "$DIST_DIR"
DMG_PATH="$DIST_DIR/QuickCookies-macOS.dmg"

log_info "正在建立干净的 DMG 专属打包源目录... / Creating clean DMG source directory..."
DMG_SOURCE="$BUILD_DIR/DmgSource"
rm -rf "$DMG_SOURCE"
mkdir -p "$DMG_SOURCE"

# Copy signed App only to prevent compilation clutter
cp -R "$APP_PATH" "$DMG_SOURCE/"

log_info "开始调用 create-dmg 封装安装包... / Packaging DMG with create-dmg..."

# Locate app bundle icon
ICON_PATH="./QuickCookies/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.icns"
if [ ! -f "$ICON_PATH" ]; then
    ICON_PATH="$APP_PATH/Contents/Resources/AppIcon.icns"
fi

create-dmg \
  --volname "Quick Cookies" \
  --volicon "$ICON_PATH" \
  --window-size 500 340 \
  --icon-size 90 \
  --icon "QuickCookies.app" 130 110 \
  --hide-extension "QuickCookies.app" \
  --app-drop-link 370 110 \
  "$DMG_PATH" \
  "$DMG_SOURCE/"

log_success "DMG 封装打包顺利完成！ / DMG packaging completed successfully!"
echo -e "${GREEN}成果物路径 / Artifact path: ${YELLOW}$DMG_PATH${NC}"

# ==========================================
# 步骤 6: 自动拉起 Finder 展现成果 (Premium 体验)
# Step 6: Reveal DMG in Finder
# ==========================================
log_info "正在拉起 Finder... / Opening output folder in Finder..."
open "$DIST_DIR"
log_success "已在 Finder 中打开最终打包输出目录。 / Opened destination folder in Finder."
echo -e "${BLUE}=======================================${NC}"
