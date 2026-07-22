# NTHU.CC VPN 修复与配置指南

> 一站式解决 NTHU.CC VPN 与 Clash 客户端冲突，以及 Codex CLI 代理统一配置问题。

## 目录

- [快速开始](#快速开始)
- [常见问题](#常见问题)
  - [NTHU.CC 显示"网络错误"](#nthucc-显示网络错误)
  - [Clash Verge 导致 VPN 失效](#clash-verge-导致-vpn-失效)
  - [Codex CLI 无法联网](#codex-cli-无法联网)
- [架构说明](#架构说明)
- [脚本说明](#脚本说明)
- [端口规划](#端口规划)
- [故障排查](#故障排查)

---

## 快速开始

### 正常使用（NTHU.CC App 已登录）

1. 打开 NTHU.CC App
2. 确保 VPN 已连接
3. 开启系统代理：

```bash
networksetup -setwebproxy Wi-Fi 127.0.0.1 6382
networksetup -setsecurewebproxy Wi-Fi 127.0.0.1 6382
```

4. 同步 Codex 代理：

```bash
bash sync-proxy-env.sh
```

### 无法登录时的备用方案

```bash
# 使用独立代理（不依赖 App）
bash vpn-standalone.sh
```

---

## 常见问题

### NTHU.CC 显示"网络错误"

**根因**：订阅 Token 失效。通常是因为同一账号被多个客户端使用，服务器端自动吊销 Token。

**解决方法**：

1. 确保系统代理开启（如果是首次启动需要先建立独立代理）：
   ```bash
   bash vpn-standalone.sh
   ```

2. 从终端启动 NTHU.CC（传递代理环境变量）：
   ```bash
   HTTP_PROXY="http://127.0.0.1:7892" \
   HTTPS_PROXY="http://127.0.0.1:7892" \
   http_proxy="http://127.0.0.1:7892" \
   https_proxy="http://127.0.0.1:7892" \
   /Applications/NTHU.CC.app/Contents/MacOS/NTHU.CC
   ```

3. 登录你的 NTHU.CC 账号

4. 登录成功后，App 自动获取新 Token，切换到 6382 端口。

### Clash Verge 导致 VPN 失效

**症状**：安装 Clash Verge Rev 后 NTHU.CC 无法连接，代理端口混乱。

**根因**：
1. Clash Verge 的 LaunchDaemon 以 root 权限常驻，与 NTHU.CC 冲突
2. 导入同名订阅 → Token 被吊销
3. 环境变量残留指向错误端口

**彻底卸载 Clash Verge**：

```bash
# 卸载系统服务
sudo launchctl unload /Library/LaunchDaemons/io.github.clash-verge-rev.clash-verge-rev.service.plist
sudo rm /Library/LaunchDaemons/io.github.clash-verge-rev.clash-verge-rev.service.plist

# 清理进程
sudo kill -9 $(pgrep -f clash-verge)

# 删除文件和配置
sudo rm -rf /Library/PrivilegedHelperTools/io.github.clash-verge-rev.clash-verge-rev.service.bundle
rm -rf ~/Library/Application\ Support/io.github.clash-verge-rev.clash-verge-rev/

# 清理代理残留
networksetup -setwebproxystate Wi-Fi off
networksetup -setsecurewebproxystate Wi-Fi off
launchctl unsetenv HTTP_PROXY
launchctl unsetenv HTTPS_PROXY
```

然后重新安装 NTHU.CC 并登录。

### Codex CLI 无法联网

**症状**：Codex 报网络错误，但浏览器可以正常翻墙。

**根因**：Codex 的代理由 `~/.codex/sync-proxy-env.sh` 从系统代理同步。如果脚本硬编码了错误的端口，或者系统代理未开启，Codex 就会拿到死端口。

**解决方法**：

1. 确保系统代理已开启并指向正确端口：
   ```bash
   networksetup -setwebproxy Wi-Fi 127.0.0.1 6382
   networksetup -setsecurewebproxy Wi-Fi 127.0.0.1 6382
   ```

2. 运行同步脚本：
   ```bash
   bash sync-proxy-env.sh
   ```

3. 验证：
   ```bash
   cat ~/.codex/.env
   # 应该显示: HTTP_PROXY="http://127.0.0.1:6382"
   ```

---

## 架构说明

```
┌──────────────────────────────────────────────────┐
│                  NTHU.CC App                      │
│  ┌────────────────────────────────────────────┐  │
│  │  AtlasCore (Mihomo Meta)                    │  │
│  │  ├─ HTTP Proxy  :6382                      │  │
│  │  ├─ SOCKS Proxy :动态                       │  │
│  │  └─ API          :9090                      │  │
│  └────────────────────────────────────────────┘  │
│  ┌────────────────────────────────────────────┐  │
│  │  VPN.appex (Network Extension)              │  │
│  │  系统级 VPN 路由                             │  │
│  └────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────┘
                         │
         ┌───────────────┼───────────────┐
         ▼               ▼               ▼
   ┌──────────┐   ┌──────────┐   ┌──────────┐
   │ 系统代理  │   │  Codex   │   │ 其他 GUI │
   │ (Wi-Fi)  │   │  .env    │   │ 应用     │
   │          │   │          │   │          │
   │ :6382    │   │ :6382    │   │ launchctl │
   └──────────┘   └──────────┘   └──────────┘
```

**核心原则**：所有组件指向**同一个端口**。

### 统一代理流程

```
NTHU.CC App 启动
  → 获取订阅（通过代理，如果网络受限）
    → 启动 AtlasCore (端口 6382)
      → 开启系统代理 → 127.0.0.1:6382
        → sync-proxy-env.sh 读取系统代理
          → 写入 Codex .env + launchctl env
            → ✅ 所有组件统一
```

### 端口规划

| 端口 | 用途 | 使用场景 |
|------|------|----------|
| **6382** | **统一代理端口** | NTHU.CC App 登录后的生产端口 |
| 7892 | 独立代理端口 | App 无法登录时的备用方案 |
| 9090 | Clash API | 配合 6382 使用 |
| 9092 | Clash API（备用） | 配合 7892 使用 |

---

## 脚本说明

### `sync-proxy-env.sh`

Codex 代理同步脚本。放置于 `~/.codex/sync-proxy-env.sh`。

**工作原理**：
1. 读取 macOS 系统代理设置 (`scutil --proxy`)
2. 若系统代理已设置 → 使用系统代理端口
3. 若系统代理未设置 → 自动检测运行中的 Clash 进程端口
4. 都检测不到 → 跳过（不强制设置，避免死端口）
5. 写入 `~/.codex/.env` 和 `launchctl setenv`

**修复前的问题**：旧版硬编码了 fallback 端口 `6382`，当 NTHU.CC 未启动时也会强制设置，导致 Codex 连到死端口。

### `vpn-standalone.sh`

独立 VPN 启动脚本。当 NTHU.CC App 无法登录（鸡生蛋问题）时使用。

**工作原理**：
1. 复制 AtlasCore 为 `proxy_core`（改名为避免被 App 杀掉）
2. 用预置的完整订阅配置启动代理（端口 7892）
3. 设置系统代理 → 运行 sync-proxy-env.sh → 同步 Codex
4. 验证 Google 可达性

### `vpn-stop.sh`

停止所有代理组件。

---

## 故障排查

### 检查代理状态

```bash
# 查看是否有 Clash 进程在运行
ps aux | grep -E 'AtlasCore|proxy_core' | grep -v grep

# 查看监听端口
lsof -iTCP -sTCP:LISTEN -P -n | grep -E 'AtlasCore|proxy_core'

# 测试代理是否工作
curl -s --proxy http://127.0.0.1:6382 --connect-timeout 5 \
  https://www.google.com -o /dev/null -w "%{http_code}\n"
```

### 检查环境变量

```bash
# Shell 环境变量
echo $HTTP_PROXY
echo $HTTPS_PROXY

# launchctl 环境变量（GUI 应用使用）
launchctl getenv HTTP_PROXY
launchctl getenv HTTPS_PROXY

# Codex 配置文件
cat ~/.codex/.env
```

### 手动获取订阅

```bash
# 登录获取新 Token
curl -s -X POST "https://ooo.subscribe-streaming.com/api/v1/passport/auth/login" \
  -H "Content-Type: application/json" \
  -H "User-Agent: clash.meta" \
  -d '{"email":"你的邮箱","password":"你的密码"}'

# 用 Token 获取订阅配置
curl -s -H "User-Agent: clash.meta" \
  "https://ooo.subscribe-streaming.com/api/v1/client/subscribe?token=<TOKEN>"
```

> ⚠️ 订阅服务器会检查 User-Agent，必须使用 `clash.meta` 或类似的 UA，否则返回 403。

### 快速诊断命令

```bash
# 一键检查所有代理状态
echo "=== 进程 ===" && pgrep -fl "AtlasCore|proxy_core" || echo "无代理进程"
echo "=== 端口 ===" && lsof -iTCP -sTCP:LISTEN -P -n 2>/dev/null | grep -E '6382|7892|9090'
echo "=== 系统代理 ===" && networksetup -getwebproxy Wi-Fi | grep -E "Enabled|Server|Port"
echo "=== Codex .env ===" && head -2 ~/.codex/.env 2>/dev/null || echo "文件不存在"
echo "=== Google 测试 ===" && curl -s --proxy http://127.0.0.1:6382 --connect-timeout 5 https://www.google.com -o /dev/null -w "HTTP %{http_code}\n"
```

---

## 许可证

MIT

---

> 📅 2026-07-22 · Mac (Apple Silicon) · macOS 15.3.1 · NTHU.CC v1.41.0
