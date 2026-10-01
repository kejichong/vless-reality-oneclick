#!/usr/bin/env bash
# VLESS + REALITY + XTLS Vision one-click installer for Ubuntu/Debian.
# Uses the official XTLS installer and performs an end-to-end local proxy test.
# Script version: 1.0.0

set -Eeuo pipefail
umask 077

XRAY_BIN="/usr/local/bin/xray"
CONFIG_DIR="/usr/local/etc/xray"
CONFIG_FILE="${CONFIG_DIR}/config.json"
SECRETS_FILE="/root/vless-reality-secrets.env"
CLIENT_LINK_FILE="/root/vless-reality-client.txt"
INSTALLER_URL="https://github.com/XTLS/Xray-install/raw/main/install-release.sh"
SCRIPT_NAME="vless-reality-oneclick"
SCRIPT_VERSION="1.0.0"

PORT=443
TARGET="gateway.icloud.com"
SERVER_IP=""
XRAY_VERSION=""
ASSUME_YES=0
SHOW_LINK=0

TEMP_INSTALLER=""
CANDIDATE_CONFIG=""
TEMP_CLIENT_CONFIG=""
TEMP_CLIENT_LOG=""
TEST_PID=""
BACKUP_FILE=""
HAD_OLD_CONFIG=0
CONFIG_APPLIED=0

log() {
  printf '\n\033[1;32m[%s]\033[0m %s\n' "$(date '+%H:%M:%S')" "$*"
}

warn() {
  printf '\033[1;33m警告：%s\033[0m\n' "$*" >&2
}

die() {
  printf '\033[1;31m错误：%s\033[0m\n' "$*" >&2
  return 1
}

usage() {
  cat <<'EOF'
用法：
  bash vless-reality-oneclick.sh [选项]

选项：
  --server-ip IP或域名   写入客户端链接的服务器公网地址
  --port 端口            服务端 TCP 端口，默认 443
  --target 域名          REALITY 目标站/SNI，默认 gateway.icloud.com
  --xray-version 版本    指定 Xray 版本，例如 v26.7.28；默认官方稳定版
  --yes                  覆盖已有 Xray 配置时不再确认
  --show-link            成功后在终端显示完整客户端链接
  -v, --version          显示脚本版本
  -h, --help             显示帮助

示例：
  bash vless-reality-oneclick.sh
  bash vless-reality-oneclick.sh --server-ip 203.0.113.10 --show-link
  bash vless-reality-oneclick.sh --target www.apple.com
EOF
}

cleanup() {
  set +e
  if [[ -n "$TEST_PID" ]]; then
    kill "$TEST_PID" 2>/dev/null || true
    wait "$TEST_PID" 2>/dev/null || true
  fi
  [[ -n "$TEMP_INSTALLER" ]] && rm -f "$TEMP_INSTALLER"
  [[ -n "$CANDIDATE_CONFIG" ]] && rm -f "$CANDIDATE_CONFIG"
  [[ -n "$TEMP_CLIENT_CONFIG" ]] && rm -f "$TEMP_CLIENT_CONFIG"
  [[ -n "$TEMP_CLIENT_LOG" ]] && rm -f "$TEMP_CLIENT_LOG"
  return 0
}

rollback() {
  local rc="${1:-$?}"
  trap - ERR INT TERM
  set +e
  cleanup

  if [[ "$CONFIG_APPLIED" -eq 1 ]]; then
    warn "部署失败，正在恢复原配置。"
    if [[ "$HAD_OLD_CONFIG" -eq 1 && -f "$BACKUP_FILE" ]]; then
      cp -a "$BACKUP_FILE" "$CONFIG_FILE"
      systemctl restart xray || true
    else
      rm -f "$CONFIG_FILE"
      systemctl stop xray || true
    fi
  fi
  exit "$rc"
}

trap cleanup EXIT
trap 'rollback $?' ERR
trap 'rollback 130' INT
trap 'rollback 143' TERM

while [[ $# -gt 0 ]]; do
  case "$1" in
    --server-ip)
      [[ $# -ge 2 ]] || die "--server-ip 缺少参数"
      SERVER_IP="$2"
      shift 2
      ;;
    --port)
      [[ $# -ge 2 ]] || die "--port 缺少参数"
      PORT="$2"
      shift 2
      ;;
    --target)
      [[ $# -ge 2 ]] || die "--target 缺少参数"
      TARGET="$2"
      shift 2
      ;;
    --xray-version)
      [[ $# -ge 2 ]] || die "--xray-version 缺少参数"
      XRAY_VERSION="$2"
      shift 2
      ;;
    --yes)
      ASSUME_YES=1
      shift
      ;;
    --show-link)
      SHOW_LINK=1
      shift
      ;;
    -v|--version)
      printf '%s v%s\n' "$SCRIPT_NAME" "$SCRIPT_VERSION"
      exit 0
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "未知参数：$1"
      ;;
  esac
done

[[ "$EUID" -eq 0 ]] || die "请使用 root 用户运行此脚本。"
command -v apt-get >/dev/null 2>&1 || die "此脚本目前仅支持 Ubuntu/Debian（需要 apt-get）。"
[[ "$PORT" =~ ^[0-9]+$ ]] || die "端口必须是数字。"
(( PORT >= 1 && PORT <= 65535 )) || die "端口必须在 1 到 65535 之间。"

TARGET="${TARGET#https://}"
TARGET="${TARGET#http://}"
TARGET="${TARGET%%/*}"
TARGET="${TARGET%%:*}"
[[ "$TARGET" =~ ^[A-Za-z0-9.-]+$ ]] || die "目标站必须是普通域名，不能包含路径。"

if [[ -f "$CONFIG_FILE" && "$ASSUME_YES" -ne 1 ]]; then
  warn "检测到已有 Xray 配置：${CONFIG_FILE}"
  warn "继续会备份并替换整个配置文件；不适合与其他 Xray 入站共用。"
  read -r -p "确认继续请输入 OVERWRITE：" CONFIRM
  [[ "$CONFIRM" == "OVERWRITE" ]] || die "用户取消。"
fi

if command -v ss >/dev/null 2>&1; then
  LISTENER="$(ss -H -lntp "( sport = :${PORT} )" 2>/dev/null || true)"
  if [[ -n "$LISTENER" && "$LISTENER" != *'"xray"'* ]]; then
    printf '%s\n' "$LISTENER" >&2
    die "TCP ${PORT} 已被其他程序占用。"
  fi
fi

log "安装基础依赖"
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y \
  curl unzip openssl ca-certificates python3 iproute2

if command -v ss >/dev/null 2>&1; then
  LISTENER="$(ss -H -lntp "( sport = :${PORT} )" 2>/dev/null || true)"
  if [[ -n "$LISTENER" && "$LISTENER" != *'"xray"'* ]]; then
    printf '%s\n' "$LISTENER" >&2
    die "TCP ${PORT} 已被其他程序占用。"
  fi
fi

if [[ -z "$SERVER_IP" ]]; then
  DETECTED_IP="$(curl -4 -fsS --connect-timeout 5 https://api.ipify.org 2>/dev/null || true)"
  if [[ -n "$DETECTED_IP" ]]; then
    read -r -p "服务器公网 IP 或域名 [${DETECTED_IP}]：" SERVER_IP
    SERVER_IP="${SERVER_IP:-$DETECTED_IP}"
  else
    read -r -p "服务器公网 IP 或域名：" SERVER_IP
  fi
fi

SERVER_IP="${SERVER_IP//[[:space:]]/}"
[[ -n "$SERVER_IP" ]] || die "服务器公网地址不能为空。"

log "检查 REALITY 目标站 ${TARGET}"
if ! curl -sS -o /dev/null --connect-timeout 10 "https://${TARGET}/"; then
  die "无法从服务器连接目标站 ${TARGET}:443，请使用 --target 更换目标站。"
fi

log "通过 XTLS 官方脚本安装或更新 Xray"
TEMP_INSTALLER="$(mktemp --suffix=.sh /tmp/xray-install.XXXXXX)"
curl -fsSL "$INSTALLER_URL" -o "$TEMP_INSTALLER"
chmod 700 "$TEMP_INSTALLER"
if [[ -n "$XRAY_VERSION" ]]; then
  bash "$TEMP_INSTALLER" install --version "$XRAY_VERSION"
else
  bash "$TEMP_INSTALLER" install
fi

[[ -x "$XRAY_BIN" ]] || die "Xray 安装后未找到：${XRAY_BIN}"
mkdir -p "$CONFIG_DIR"

log "生成 UUID、REALITY 密钥和 ShortID"
UUID="$("$XRAY_BIN" uuid)"
KEY_OUTPUT="$("$XRAY_BIN" x25519)"
PRIVATE_KEY="$(printf '%s\n' "$KEY_OUTPUT" | awk -F': ' '/^PrivateKey/{print $2; exit}')"
PASSWORD="$(printf '%s\n' "$KEY_OUTPUT" | awk -F': ' '/^Password/{print $2; exit}')"
SHORT_ID="$(openssl rand -hex 8)"

if [[ ${#UUID} -ne 36 || ${#PRIVATE_KEY} -ne 43 || ${#PASSWORD} -ne 43 || ${#SHORT_ID} -ne 16 ]]; then
  die "生成的认证参数长度异常。"
fi

if [[ -f "$CONFIG_FILE" ]]; then
  HAD_OLD_CONFIG=1
  BACKUP_FILE="${CONFIG_FILE}.backup.$(date +%Y%m%d%H%M%S)"
  cp -a "$CONFIG_FILE" "$BACKUP_FILE"
fi

CANDIDATE_CONFIG="$(mktemp --suffix=.json /tmp/vless-reality-server.XXXXXX)"
export PORT TARGET UUID PRIVATE_KEY SHORT_ID CANDIDATE_CONFIG
python3 - <<'PY'
import json
import os

config = {
    "log": {"loglevel": "warning"},
    "inbounds": [{
        "tag": "vless-reality-in",
        "listen": "0.0.0.0",
        "port": int(os.environ["PORT"]),
        "protocol": "vless",
        "settings": {
            "clients": [{
                "id": os.environ["UUID"],
                "flow": "xtls-rprx-vision",
                "email": "primary",
            }],
            "decryption": "none",
        },
        "streamSettings": {
            "network": "raw",
            "security": "reality",
            "realitySettings": {
                "show": False,
                "target": os.environ["TARGET"] + ":443",
                "xver": 0,
                "serverNames": [os.environ["TARGET"]],
                "privateKey": os.environ["PRIVATE_KEY"],
                "shortIds": [os.environ["SHORT_ID"]],
            },
        },
        "sniffing": {
            "enabled": True,
            "destOverride": ["http", "tls", "quic"],
            "routeOnly": True,
        },
    }],
    "outbounds": [
        {"protocol": "freedom", "tag": "direct"},
        {"protocol": "blackhole", "tag": "blocked"},
    ],
}

with open(os.environ["CANDIDATE_CONFIG"], "w", encoding="utf-8") as f:
    json.dump(config, f, indent=2)
    f.write("\n")
os.chmod(os.environ["CANDIDATE_CONFIG"], 0o600)
PY

log "检查服务端配置"
"$XRAY_BIN" run -test -config "$CANDIDATE_CONFIG"
install -m 644 "$CANDIDATE_CONFIG" "$CONFIG_FILE"
CONFIG_APPLIED=1

log "启动 Xray"
systemctl enable xray >/dev/null
systemctl restart xray

for ((attempt = 0; attempt < 50; attempt++)); do
  if systemctl is-active --quiet xray && ss -H -lnt "( sport = :${PORT} )" 2>/dev/null | grep -q LISTEN; then
    break
  fi
  sleep 0.1
done

systemctl is-active --quiet xray || die "Xray 没有保持运行。"
ss -H -lnt "( sport = :${PORT} )" 2>/dev/null | grep -q LISTEN || die "Xray 未监听 TCP ${PORT}。"

if command -v ufw >/dev/null 2>&1 && ufw status 2>/dev/null | grep -q '^Status: active'; then
  log "UFW 已启用，放行 TCP ${PORT}"
  ufw allow "${PORT}/tcp" >/dev/null
fi

LINK_HOST="$SERVER_IP"
if [[ "$LINK_HOST" == *:* && "$LINK_HOST" != \[*\] ]]; then
  LINK_HOST="[${LINK_HOST}]"
fi

printf 'UUID=%q\nPRIVATE_KEY=%q\nPASSWORD=%q\nSHORT_ID=%q\nTARGET=%q\nPORT=%q\n' \
  "$UUID" "$PRIVATE_KEY" "$PASSWORD" "$SHORT_ID" "$TARGET" "$PORT" > "$SECRETS_FILE"

printf 'vless://%s@%s:%s?encryption=none&flow=xtls-rprx-vision&security=reality&sni=%s&fp=chrome&pbk=%s&sid=%s&type=tcp&headerType=none#VLESS-Reality-v%s\n' \
  "$UUID" "$LINK_HOST" "$PORT" "$TARGET" "$PASSWORD" "$SHORT_ID" "$SCRIPT_VERSION" > "$CLIENT_LINK_FILE"
chmod 600 "$SECRETS_FILE" "$CLIENT_LINK_FILE"

log "执行 VLESS + REALITY 端到端自测"
SOCKS_PORT=""
for ((candidate_port = 18080; candidate_port <= 18120; candidate_port++)); do
  if ! ss -H -lnt "( sport = :${candidate_port} )" 2>/dev/null | grep -q .; then
    SOCKS_PORT="$candidate_port"
    break
  fi
done
[[ -n "$SOCKS_PORT" ]] || die "无法找到本地自测端口。"

TEMP_CLIENT_CONFIG="$(mktemp --suffix=.json /tmp/vless-reality-client.XXXXXX)"
TEMP_CLIENT_LOG="$(mktemp --suffix=.log /tmp/vless-reality-client.XXXXXX)"
export SOCKS_PORT TEMP_CLIENT_CONFIG PASSWORD
python3 - <<'PY'
import json
import os

config = {
    "log": {"loglevel": "warning"},
    "inbounds": [{
        "listen": "127.0.0.1",
        "port": int(os.environ["SOCKS_PORT"]),
        "protocol": "socks",
        "settings": {"udp": False},
    }],
    "outbounds": [{
        "protocol": "vless",
        "settings": {
            "vnext": [{
                "address": "127.0.0.1",
                "port": int(os.environ["PORT"]),
                "users": [{
                    "id": os.environ["UUID"],
                    "encryption": "none",
                    "flow": "xtls-rprx-vision",
                }],
            }],
        },
        "streamSettings": {
            "network": "raw",
            "security": "reality",
            "realitySettings": {
                "serverName": os.environ["TARGET"],
                "fingerprint": "chrome",
                "password": os.environ["PASSWORD"],
                "shortId": os.environ["SHORT_ID"],
                "spiderX": "",
            },
        },
    }],
}

with open(os.environ["TEMP_CLIENT_CONFIG"], "w", encoding="utf-8") as f:
    json.dump(config, f, indent=2)
    f.write("\n")
os.chmod(os.environ["TEMP_CLIENT_CONFIG"], 0o600)
PY

"$XRAY_BIN" run -test -config "$TEMP_CLIENT_CONFIG" >/dev/null
"$XRAY_BIN" run -config "$TEMP_CLIENT_CONFIG" >"$TEMP_CLIENT_LOG" 2>&1 &
TEST_PID=$!

for ((attempt = 0; attempt < 50; attempt++)); do
  if ss -H -lnt "( sport = :${SOCKS_PORT} )" 2>/dev/null | grep -q LISTEN; then
    break
  fi
  sleep 0.1
done
ss -H -lnt "( sport = :${SOCKS_PORT} )" 2>/dev/null | grep -q LISTEN || die "临时测试客户端启动失败。"

SELF_TEST_HTTP="$(curl -sS -o /dev/null -w '%{http_code}' \
  --socks5-hostname "127.0.0.1:${SOCKS_PORT}" \
  --connect-timeout 10 --max-time 20 \
  https://www.apple.com/ || true)"

[[ "$SELF_TEST_HTTP" != "000" ]] || die "端到端代理测试失败。请更换 --target 后重试。"

kill "$TEST_PID" 2>/dev/null || true
wait "$TEST_PID" 2>/dev/null || true
TEST_PID=""

trap - ERR INT TERM
CONFIG_APPLIED=0

printf '\n\033[1;32m部署成功。\033[0m\n'
printf '脚本版本：v%s\n' "$SCRIPT_VERSION"
printf '协议：VLESS + REALITY + XTLS Vision\n'
printf '传输：TCP/RAW\n'
printf '端口：%s\n' "$PORT"
printf '目标站：%s\n' "$TARGET"
printf 'Xray：%s\n' "$("$XRAY_BIN" version | sed -n '1p')"
printf '端到端自测 HTTP：%s\n' "$SELF_TEST_HTTP"
printf '客户端链接文件：%s\n' "$CLIENT_LINK_FILE"
printf '凭据备份文件：%s\n' "$SECRETS_FILE"
[[ "$HAD_OLD_CONFIG" -eq 1 ]] && printf '原配置备份：%s\n' "$BACKUP_FILE"

printf '\n下一步：\n'
printf '1. 在云服务器安全组中放行 TCP %s。\n' "$PORT"
printf '2. 在 v2rayN 中更新 Xray-core。\n'
printf '3. 执行：cat %s\n' "$CLIENT_LINK_FILE"
printf '4. 私下复制 vless:// 链接并导入 v2rayN；不要截图或公开链接。\n'

if [[ "$SHOW_LINK" -eq 1 ]]; then
  printf '\n完整客户端链接（请勿公开）：\n'
  cat "$CLIENT_LINK_FILE"
fi
