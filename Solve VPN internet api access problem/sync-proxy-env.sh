#!/bin/bash
# sync-proxy-env.sh — Codex 代理环境同步脚本
# 从系统代理或运行中的 Clash 进程自动检测代理端口
# 写入 ~/.codex/.env 和 launchctl 环境变量

set -euo pipefail

CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
ENV_FILE="$CODEX_HOME/.env"

# 1. 读取 macOS 系统代理设置
proxy_host="$(scutil --proxy | awk -F': ' '/HTTPProxy :/ {print $2; exit}')"
proxy_port="$(scutil --proxy | awk -F': ' '/HTTPPort :/ {print $2; exit}')"
https_host="$(scutil --proxy | awk -F': ' '/HTTPSProxy :/ {print $2; exit}')"
https_port="$(scutil --proxy | awk -F': ' '/HTTPSPort :/ {print $2; exit}')"

# 2. 如果系统代理未设置 → 自动检测运行中的 Clash 进程
if [[ -z "${proxy_host:-}" || -z "${proxy_port:-}" ]]; then
  detected_port=$(lsof -iTCP -sTCP:LISTEN -P -n 2>/dev/null | \
    grep -E 'AtlasCore|proxy_core|clash|mihomo' | \
    grep -oE ':[0-9]+' | grep -vE '^:(909[0-9])$' | \
    head -1 | tr -d ':')

  if [[ -n "${detected_port:-}" ]]; then
    proxy_host="127.0.0.1"
    proxy_port="$detected_port"
    echo "🔍 自动检测到 Clash 端口: $proxy_port" >&2
  else
    echo "⚠️  未检测到系统代理或运行中的 Clash 进程，跳过" >&2
    exit 0
  fi
fi

# 3. HTTPS 代理默认和 HTTP 一样
if [[ -z "${https_host:-}" || -z "${https_port:-}" ]]; then
  https_host="$proxy_host"
  https_port="$proxy_port"
fi

# 4. 构建代理 URL
http_proxy_url="http://${proxy_host}:${proxy_port}"
https_proxy_url="http://${https_host}:${https_port}"
no_proxy_value="localhost,127.0.0.1,::1,*.local,192.168.0.0/16,10.0.0.0/8,172.16.0.0/12"

# 5. 写入 Codex .env
mkdir -p "$CODEX_HOME"
cat > "$ENV_FILE" <<EOF
HTTP_PROXY="$http_proxy_url"
HTTPS_PROXY="$https_proxy_url"
NO_PROXY="$no_proxy_value"
http_proxy="$http_proxy_url"
https_proxy="$https_proxy_url"
no_proxy="$no_proxy_value"
EOF

# 6. 设置 launchctl 全局环境变量（GUI 应用可用）
launchctl setenv HTTP_PROXY "$http_proxy_url"
launchctl setenv HTTPS_PROXY "$https_proxy_url"
launchctl setenv NO_PROXY "$no_proxy_value"
launchctl setenv http_proxy "$http_proxy_url"
launchctl setenv https_proxy "$https_proxy_url"
launchctl setenv no_proxy "$no_proxy_value"

echo "✅ 代理已同步: $http_proxy_url → Codex .env + launchctl" >&2
