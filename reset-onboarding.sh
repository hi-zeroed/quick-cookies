#!/bin/bash

# ==============================================================================
# Quick Cookies - Onboarding Reset Tool
# ==============================================================================
# 这个脚本用于重置应用的 UserDefaults 缓存，以便在开发时能够重新看到新手引导（Guide）。
# This script resets the app's UserDefaults cache to easily trigger the onboarding guide.

echo "======================================================"
echo "  正在重置 Quick Cookies 新手引导状态..."
echo "  Resetting Quick Cookies Onboarding State..."
echo "======================================================"

# 1. 重置 UserDefaults 域 (Reset UserDefaults Domains)
defaults delete com.quickcookies.app 2>/dev/null
defaults delete com.quickcookies.app.FinderSync 2>/dev/null

# 2. 清理沙盒偏好设置目录以防万一 (Clean sandbox preferences just in case)
if [ -d "$HOME/Library/Containers/com.quickcookies.app" ]; then
    rm -f "$HOME/Library/Containers/com.quickcookies.app/Data/Library/Preferences/com.quickcookies.app.plist"
    echo "• 已清理沙盒偏好文件 / Sandbox preference file cleaned."
fi

# 3. 刷新 Preference 守护进程缓存 (Flush Preference Daemon Cache)
killall cfprefsd 2>/dev/null

echo "======================================================"
echo "  ✅ 重置完成！ / Reset Completed!"
echo "  请现在在 Xcode 中重新编译并运行主 App。"
echo "  Please rebuild and run the main App in Xcode now."
echo "======================================================"
