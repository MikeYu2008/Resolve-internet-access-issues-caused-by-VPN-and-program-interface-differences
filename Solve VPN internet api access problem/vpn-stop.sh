#!/bin/bash
# vpn-stop.sh — 停止所有 VPN 代理组件
#
# 用法: bash vpn-stop.sh

set -euo pipefail

echo "====== 停止 VPN 代理 ======"

# 1. 停止独立代理
if pgrep -f proxy_core > /dev/null 2>&1; then
    pkill -f proxy_core 2>/dev/null
    echo "✅ 独立代理 (proxy_core) 已停止"
else
    echo "ℹ️  无独立代理运行"
fi

# 2. 关闭系统代理
networksetup -setwebproxystate Wi-Fi off 2>/dev/null
networksetup -setsecurewebproxystate Wi-Fi off 2>/dev/null
echo "✅ 系统代理已关闭"

# 3. 清除 launchctl 环境变量
launchctl unsetenv HTTP_PROXY 2>/dev/null
launchctl unsetenv HTTPS_PROXY 2>/dev/null
launchctl unsetenv http_proxy 2>/dev/null
launchctl unsetenv https_proxy 2>/dev/null
echo "✅ launchctl 环境变量已清除"

# 4. 提示
echo ""
echo "====== 代理已停止 ======"
echo "如需重新启动，执行: bash vpn-standalone.sh"
echo "如需使用 NTHU.CC App，直接打开应用即可。"
