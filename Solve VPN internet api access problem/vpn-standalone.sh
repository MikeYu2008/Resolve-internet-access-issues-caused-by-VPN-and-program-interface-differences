#!/bin/bash
# vpn-standalone.sh — NTHU.CC VPN 独立启动脚本
# 当 NTHU.CC App 无法登录时使用（鸡生蛋问题）
# 使用预置订阅配置在独立端口运行代理
#
# 用法: bash vpn-standalone.sh

set -euo pipefail

CONFIG_DIR="$HOME/Library/Application Support/com.nthucc.app/clash"
PROXY_CORE="/tmp/proxy_core"
CONFIG_FILE="$CONFIG_DIR/standalone_config.yaml"
PROXY_PORT=7892
API_PORT=9092
APP_BINARY="/Applications/NTHU.CC.app/Contents/Resources/AtlasCore_arm64"

echo "====== NTHU.CC VPN 独立模式 ======"

# 1. 检查 NTHU.CC 是否已安装
if [ ! -f "$APP_BINARY" ]; then
    echo "❌ 未找到 NTHU.CC，请先安装"
    exit 1
fi

# 2. 准备伪装代理二进制（改名避免被 App 杀掉）
if [ ! -f "$PROXY_CORE" ]; then
    cp "$APP_BINARY" "$PROXY_CORE"
    chmod 755 "$PROXY_CORE"
    echo "📦 已创建伪装代理: $PROXY_CORE"
fi

# 3. 检查订阅配置是否存在
if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ 未找到订阅配置: $CONFIG_FILE"
    echo ""
    echo "请先获取订阅配置。使用以下命令："
    echo ""
    echo "  # 1. 登录获取 Token"
    echo '  curl -s -X POST "https://ooo.subscribe-streaming.com/api/v1/passport/auth/login" \'
    echo '    -H "Content-Type: application/json" \'
    echo '    -H "User-Agent: clash.meta" \'
    echo '    -d '"'"'{"email":"你的邮箱","password":"你的密码"}'"'"''
    echo ""
    echo "  # 2. 获取订阅"
    echo '  curl -s -H "User-Agent: clash.meta" \'
    echo '    "https://ooo.subscribe-streaming.com/api/v1/client/subscribe?token=<TOKEN>" \'
    echo "    > $CONFIG_FILE"
    echo ""
    echo "  # 3. 修改端口避免冲突"
    echo "  sed -i '' 's/port: 7890/port: 7892/' $CONFIG_FILE"
    echo "  sed -i '' \"s/external-controller: '127.0.0.1:9090'/external-controller: '127.0.0.1:9092'/\" $CONFIG_FILE"
    exit 1
fi

# 4. 杀掉旧进程
if pgrep -f proxy_core > /dev/null 2>&1; then
    echo "🔄 停止旧代理进程..."
    pkill -f proxy_core 2>/dev/null
    sleep 1
fi

# 5. 启动代理
echo "🚀 启动代理..."
"$PROXY_CORE" -d "$CONFIG_DIR" -f "$CONFIG_FILE" > /dev/null 2>&1 &
sleep 3

# 6. 验证启动
if ! pgrep -f proxy_core > /dev/null 2>&1; then
    echo "❌ 代理启动失败"
    exit 1
fi

echo "✅ 代理进程已启动 (PID: $(pgrep -f proxy_core))"

# 7. 设置系统代理
networksetup -setwebproxy Wi-Fi 127.0.0.1 $PROXY_PORT
networksetup -setsecurewebproxy Wi-Fi 127.0.0.1 $PROXY_PORT
echo "✅ 系统代理: 127.0.0.1:$PROXY_PORT"

# 8. 同步 Codex 代理
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$SCRIPT_DIR/sync-proxy-env.sh" ]; then
    bash "$SCRIPT_DIR/sync-proxy-env.sh"
elif [ -f "$HOME/.codex/sync-proxy-env.sh" ]; then
    bash "$HOME/.codex/sync-proxy-env.sh"
fi

# 9. 验证连通性
echo ""
echo "--- 连通性测试 ---"
if curl -s --proxy "http://127.0.0.1:$PROXY_PORT" --connect-timeout 5 \
    https://www.google.com -o /dev/null -w "%{http_code}" | grep -q 200; then
    echo "✅ Google 可达"
else
    echo "⚠️  Google 不可达，请检查代理节点"
fi

echo ""
echo "====== 代理就绪 ======"
echo "端口:   $PROXY_PORT"
echo "API:    127.0.0.1:$API_PORT"
echo ""
echo "如需登录 NTHU.CC App，执行:"
echo "  HTTP_PROXY=http://127.0.0.1:$PROXY_PORT \\"
echo "  HTTPS_PROXY=http://127.0.0.1:$PROXY_PORT \\"
echo "  /Applications/NTHU.CC.app/Contents/MacOS/NTHU.CC"
