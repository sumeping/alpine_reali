#!/bin/sh

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

CONF_PATH="/etc/xray/config.json"
XRAY_BIN="/usr/local/bin/xray"
LOG_PATH="/var/log/xray.log"
LINK_HISTORY_PATH="/var/log/xray_node_links.history"
CERT_FILE="/etc/xray/server.crt"
KEY_FILE="/etc/xray/server.key"
DEFAULT_PORT=443
DOKODEMO_PORT=4431
USE_REALITY=0
USE_HYSTERIA=0
MODE_LABEL=""

# 端口校验
is_valid_port() {
    case "$1" in
        ''|*[!0-9]*) return 1 ;;
    esac
    [ "$1" -ge 1 ] && [ "$1" -le 65535 ]
}

# 获取架构
ARCH=$(uname -m)
case ${ARCH} in
    x86_64)  X_ARCH="64" ;;
    aarch64) X_ARCH="arm64-v8a" ;;
    *) echo "不支持的架构"; exit 1 ;;
esac

# 1. 清理函数
do_cleanup() {
    echo -e "${BLUE}正在清理旧环境...${NC}"
    [ -f /etc/init.d/xray ] && rc-service xray stop 2>/dev/null && rc-update del xray default 2>/dev/null
    rm -rf /etc/xray /usr/local/share/xray ${XRAY_BIN} ${LOG_PATH} /etc/init.d/xray
}

# 2. 安装依赖并下载
download_xray() {
    echo -e "${BLUE}安装依赖 (含 libc6-compat 兼容库)...${NC}"
    apk update && apk add curl unzip openssl ca-certificates uuidgen tar gcompat libc6-compat > /dev/null 2>&1

    echo -e "${BLUE}获取最新版本...${NC}"
# 尝试从官方 release 页面抓取
NEW_VER=$(curl -s https://github.com/XTLS/Xray-core/releases/latest | grep -oP 'v[0-9]+\.[0-9]+\.[0-9]+' | head -n 1)

# 如果抓取失败，至少给一个 2026 年的版本作为兜底
[ -z "$NEW_VER" ] && NEW_VER="v26.3.27"
    
    echo -e "${GREEN}下载版本: ${NEW_VER}${NC}"
    curl -L -o /tmp/xray.zip "https://github.com/XTLS/Xray-core/releases/download/${NEW_VER}/Xray-linux-${X_ARCH}.zip"
    
    mkdir -p /etc/xray /usr/local/share/xray /tmp/xray_tmp
    unzip -o /tmp/xray.zip -d /tmp/xray_tmp
    mv -f /tmp/xray_tmp/xray ${XRAY_BIN}
    mv -f /tmp/xray_tmp/*.dat /usr/local/share/xray/
    chmod +x ${XRAY_BIN}
    rm -rf /tmp/xray.zip /tmp/xray_tmp
}

# 3. 更新功能
do_update() {
    if [ ! -f "${XRAY_BIN}" ]; then echo -e "${RED}未安装 Xray${NC}"; exit 1; fi
    echo -e "${BLUE}保留配置更新二进制文件...${NC}"
    rc-service xray stop
    download_xray
    rc-service xray start
    echo -e "${GREEN}更新成功！${NC}"
    exit 0
}

# 4. 查看历史节点导入链接
show_link_history() {
    if [ ! -s "${LINK_HISTORY_PATH}" ]; then
        echo -e "${RED}暂无历史节点导入链接记录。${NC}"
        echo -e "首次安装成功后可使用：${BLUE}sh $0 links${NC} 查看。"
        exit 0
    fi

    echo -e "${GREEN}================ 历史节点导入链接 ================${NC}"
    cat "${LINK_HISTORY_PATH}"
    echo -e "${GREEN}===================================================${NC}"
    exit 0
}

# 5. 帮助信息
show_help() {
    echo -e "${GREEN}================ xray.sh 使用说明 ================${NC}"
    echo "用法: sh $0 [命令]"
    echo ""
    echo "可用命令:"
    echo "  (留空)        覆盖安装 / 刷新密钥（会提示选择节点类型）"
    echo "  update        保留配置，仅更新内核"
    echo "  uninstall     卸载 Xray 服务与相关文件（含历史链接）"
    echo "  links         查看历史节点导入链接"
    echo "  history       links 的别名"
    echo "  help          显示本帮助信息"
    echo "  -h, --help    显示本帮助信息"
    echo -e "${GREEN}==================================================${NC}"
    exit 0
}

# 6. 选择节点类型
choose_node_mode() {
    echo ""
    echo -e "${GREEN}请选择要运行的节点类型${NC}"
    echo "  1) Reality (VLESS)"
    echo "  2) Hysteria2"
    echo "  3) Reality + Hysteria2"
    while :; do
        printf "请输入选项 [默认: 1]: "
        read -r MODE_INPUT
        [ -z "${MODE_INPUT}" ] && MODE_INPUT="1"
        case "${MODE_INPUT}" in
            1)
                USE_REALITY=1
                USE_HYSTERIA=0
                MODE_LABEL="Reality"
                break
                ;;
            2)
                USE_REALITY=0
                USE_HYSTERIA=1
                MODE_LABEL="Hysteria2"
                break
                ;;
            3)
                USE_REALITY=1
                USE_HYSTERIA=1
                MODE_LABEL="Reality + Hysteria2"
                break
                ;;
            *)
                echo -e "${RED}无效选项，请输入 1/2/3。${NC}"
                ;;
        esac
    done
    echo -e "${BLUE}当前模式: ${MODE_LABEL}${NC}"
}

# 指令处理
if [ "$1" = "uninstall" ]; then
    do_cleanup
    rm -f "${LINK_HISTORY_PATH}"
    echo -e "${GREEN}卸载完成（已删除历史节点链接）${NC}"
    exit 0
fi
if [ "$1" = "update" ]; then do_update; fi
if [ "$1" = "links" ] || [ "$1" = "history" ]; then show_link_history; fi
if [ "$1" = "help" ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then show_help; fi
if [ -n "$1" ]; then
    echo -e "${RED}未知命令: $1${NC}"
    show_help
fi

# 交互输入监听端口（回车默认 443）
while :; do
    printf "请输入 Xray/Hysteria2 监听端口（默认: %s）: " "${DEFAULT_PORT}"
    read -r INPUT_PORT
    [ -z "${INPUT_PORT}" ] && XRAY_PORT="${DEFAULT_PORT}" && break
    if is_valid_port "${INPUT_PORT}"; then
        XRAY_PORT="${INPUT_PORT}"
        break
    fi
    echo -e "${RED}端口无效，请输入 1-65535 的数字。${NC}"
done

# 交互选择节点类型（默认只运行 Reality）
choose_node_mode

# 避免与内置 dokodemo-door 端口冲突
[ "${XRAY_PORT}" -eq "${DOKODEMO_PORT}" ] && DOKODEMO_PORT=4432

# 默认安装流程
do_cleanup
download_xray

# 4. 生成运行参数
UUID=$(${XRAY_BIN} uuid 2>/dev/null)
DEST_DOMAIN="speed.cloudflare.com"

if [ -z "${UUID}" ]; then
    echo -e "${RED}生成 UUID 失败，请检查 Xray 是否可执行。${NC}"
    exit 1
fi

if [ "${USE_REALITY}" -eq 1 ]; then
    echo -e "${BLUE}生成 Reality 密钥对...${NC}"
    X_KEYS_ALL=$(${XRAY_BIN} x25519 2>/dev/null)
    PRIVATE_KEY=$(echo "${X_KEYS_ALL}" | grep -i "Private" | awk '{print $NF}' | tr -d '\r\n ')
    PUBLIC_KEY=$(echo "${X_KEYS_ALL}" | grep -i "Public" | awk '{print $NF}' | tr -d '\r\n ')
    SHORT_ID=$(openssl rand -hex 4)
    if [ -z "${PRIVATE_KEY}" ] || [ -z "${PUBLIC_KEY}" ]; then
        echo -e "${RED}Reality 密钥提取失败，原始输出如下：${NC}"
        echo "${X_KEYS_ALL}"
        exit 1
    fi
fi

if [ "${USE_HYSTERIA}" -eq 1 ]; then
    echo -e "${BLUE}生成 Hysteria2 TLS 证书...${NC}"
    openssl req -x509 -nodes -newkey rsa:2048 -keyout ${KEY_FILE} -out ${CERT_FILE} -days 3650 -subj "/CN=${DEST_DOMAIN}" > /dev/null 2>&1
    CERT_PIN=$(openssl x509 -noout -fingerprint -sha256 -in ${CERT_FILE} | cut -d'=' -f2)
    if [ -z "${CERT_PIN}" ]; then
        echo -e "${RED}证书指纹提取失败，请检查 openssl 输出。${NC}"
        exit 1
    fi
fi

# 5. 按模式写入配置
if [ "${USE_REALITY}" -eq 1 ] && [ "${USE_HYSTERIA}" -eq 1 ]; then
cat << CONF > ${CONF_PATH}
{
    "log": { "access": "${LOG_PATH}", "loglevel": "info" },
    "inbounds": [
        {
            "tag": "dokodemo-in",
            "port": ${DOKODEMO_PORT},
            "protocol": "dokodemo-door",
            "settings": { "address": "${DEST_DOMAIN}", "port": 443, "network": "tcp" },
            "sniffing": { "enabled": true, "destOverride": ["tls"], "routeOnly": true }
        },
        {
            "listen": "0.0.0.0",
            "port": ${XRAY_PORT},
            "protocol": "vless",
            "settings": {
                "clients": [{ "id": "${UUID}", "flow": "xtls-rprx-vision" }],
                "decryption": "none"
            },
            "streamSettings": {
                "network": "tcp",
                "security": "reality",
                "realitySettings": {
                    "dest": "127.0.0.1:${DOKODEMO_PORT}",
                    "serverNames": ["${DEST_DOMAIN}"],
                    "privateKey": "${PRIVATE_KEY}",
                    "shortIds": ["${SHORT_ID}"],
                    "fingerprint": "random"
                }
            },
            "sniffing": { "enabled": true, "destOverride": ["http", "tls", "quic"], "routeOnly": true }
        },
        {
            "listen": "0.0.0.0",
            "port": ${XRAY_PORT},
            "protocol": "hysteria",
            "settings": {
                "version": 2,
                "clients": [{ "auth": "${UUID}" }]
            },
            "streamSettings": {
                "network": "hysteria",
                "hysteriaSettings": { "version": 2 },
                "security": "tls",
                "tlsSettings": {
                    "alpn": ["h3"],
                    "certificates": [{
                        "certificateFile": "${CERT_FILE}",
                        "keyFile": "${KEY_FILE}"
                    }]
                }
            }
        }
    ],
    "outbounds": [
        { "protocol": "freedom", "settings": { "domainStrategy": "UseIP" }, "tag": "direct" },
        { "protocol": "blackhole", "tag": "block" }
    ],
    "routing": {
        "rules": [
            {
                "type": "field",
                "inboundTag": ["dokodemo-in"],
                "domain": ["${DEST_DOMAIN}"],
                "outboundTag": "direct"
            },
            {
                "type": "field",
                "inboundTag": ["dokodemo-in"],
                "outboundTag": "block"
            }
        ]
    }
}
CONF
elif [ "${USE_REALITY}" -eq 1 ]; then
cat << CONF > ${CONF_PATH}
{
    "log": { "access": "${LOG_PATH}", "loglevel": "info" },
    "inbounds": [
        {
            "tag": "dokodemo-in",
            "port": ${DOKODEMO_PORT},
            "protocol": "dokodemo-door",
            "settings": { "address": "${DEST_DOMAIN}", "port": 443, "network": "tcp" },
            "sniffing": { "enabled": true, "destOverride": ["tls"], "routeOnly": true }
        },
        {
            "listen": "0.0.0.0",
            "port": ${XRAY_PORT},
            "protocol": "vless",
            "settings": {
                "clients": [{ "id": "${UUID}", "flow": "xtls-rprx-vision" }],
                "decryption": "none"
            },
            "streamSettings": {
                "network": "tcp",
                "security": "reality",
                "realitySettings": {
                    "dest": "127.0.0.1:${DOKODEMO_PORT}",
                    "serverNames": ["${DEST_DOMAIN}"],
                    "privateKey": "${PRIVATE_KEY}",
                    "shortIds": ["${SHORT_ID}"],
                    "fingerprint": "random"
                }
            },
            "sniffing": { "enabled": true, "destOverride": ["http", "tls", "quic"], "routeOnly": true }
        }
    ],
    "outbounds": [
        { "protocol": "freedom", "settings": { "domainStrategy": "UseIP" }, "tag": "direct" },
        { "protocol": "blackhole", "tag": "block" }
    ],
    "routing": {
        "rules": [
            {
                "type": "field",
                "inboundTag": ["dokodemo-in"],
                "domain": ["${DEST_DOMAIN}"],
                "outboundTag": "direct"
            },
            {
                "type": "field",
                "inboundTag": ["dokodemo-in"],
                "outboundTag": "block"
            }
        ]
    }
}
CONF
else
cat << CONF > ${CONF_PATH}
{
    "log": { "access": "${LOG_PATH}", "loglevel": "info" },
    "inbounds": [
        {
            "listen": "0.0.0.0",
            "port": ${XRAY_PORT},
            "protocol": "hysteria",
            "settings": {
                "version": 2,
                "clients": [{ "auth": "${UUID}" }]
            },
            "streamSettings": {
                "network": "hysteria",
                "hysteriaSettings": { "version": 2 },
                "security": "tls",
                "tlsSettings": {
                    "alpn": ["h3"],
                    "certificates": [{
                        "certificateFile": "${CERT_FILE}",
                        "keyFile": "${KEY_FILE}"
                    }]
                }
            }
        }
    ],
    "outbounds": [
        { "protocol": "freedom", "settings": { "domainStrategy": "UseIP" }, "tag": "direct" },
        { "protocol": "blackhole", "tag": "block" }
    ]
}
CONF
fi

# 6. 服务配置
cat << 'SERVICE' > /etc/init.d/xray
#!/sbin/openrc-run
description="Xray Service"
command="/usr/local/bin/xray"
command_args="run -c /etc/xray/config.json"
command_background="yes"
pidfile="/run/${RC_SVCNAME}.pid"
depend() { need net; after firewall; }
SERVICE
chmod +x /etc/init.d/xray
rc-update add xray default
rc-service xray restart

# 7. 分离双栈输出
sleep 2
PID=$(pidof xray)
IP4=$(curl -s4 ifconfig.me)
IP6=$(curl -s6 ifconfig.me)
NOW_TS=$(date '+%Y-%m-%d %H:%M:%S %z')

echo ""
echo -e "${GREEN}================ 安装完成 (模式: ${MODE_LABEL}) ===================${NC}"
[ -n "$PID" ] && echo -e "运行状态: ${GREEN}运行中 (PID: $PID)${NC}" || echo -e "运行状态: ${RED}启动失败${NC}"
echo -e "配置文件: ${BLUE}${CONF_PATH}${NC}"
echo "------------------------------------------------"

# IPv4 节点
if [ -n "$IP4" ]; then
    if [ "${USE_REALITY}" -eq 1 ]; then
        REALITY_V4_LINK="vless://${UUID}@${IP4}:${XRAY_PORT}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${DEST_DOMAIN}&fp=random&pbk=${PUBLIC_KEY}&sid=${SHORT_ID}&type=tcp&headerType=none#Reality_V4"
        echo -e "${BLUE}[IPv4 reality节点信息]${NC}"
        echo -e "v2RayN: ${REALITY_V4_LINK}"
        echo -e "Clash: - {name: Reality_V4, type: vless, server: '${IP4}', port: ${XRAY_PORT}, uuid: ${UUID}, udp: true, tls: true, flow: xtls-rprx-vision, servername: ${DEST_DOMAIN}, network: tcp, reality-opts: {public-key: ${PUBLIC_KEY}, short-id: ${SHORT_ID}}, client-fingerprint: random}"
        echo ""
        {
            echo "[${NOW_TS}] Reality_V4"
            echo "${REALITY_V4_LINK}"
            echo ""
        } >> "${LINK_HISTORY_PATH}"
    fi
    if [ "${USE_HYSTERIA}" -eq 1 ]; then
        HY2_V4_LINK="hysteria2://${UUID}@${IP4}:${XRAY_PORT}?sni=${DEST_DOMAIN}&insecure=0&allowInsecure=0&pinSHA256=${CERT_PIN}#Hysteria_V4"
        echo -e "${BLUE}[IPv4 Hysteria2节点信息]${NC}"
        echo -e "${HY2_V4_LINK}"
        echo -e "Clash: - {name: Hysteria_V4, type: hysteria2, server: ${IP4}, port: ${XRAY_PORT}, password: ${UUID}, up: '100 Mbps', down: '200 Mbps', sni: ${DEST_DOMAIN}, skip-cert-verify: false, fingerprint: '${CERT_PIN}', alpn: [h3]}"
        echo ""
        {
            echo "[${NOW_TS}] Hysteria_V4"
            echo "${HY2_V4_LINK}"
            echo ""
        } >> "${LINK_HISTORY_PATH}"
    fi
fi

# IPv6 节点
if [ -n "$IP6" ]; then
    if [ "${USE_REALITY}" -eq 1 ]; then
        REALITY_V6_LINK="vless://${UUID}@[${IP6}]:${XRAY_PORT}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${DEST_DOMAIN}&fp=random&pbk=${PUBLIC_KEY}&sid=${SHORT_ID}&type=tcp&headerType=none#Reality_V6"
        echo -e "${BLUE}[IPv6 reality节点信息]${NC}"
        echo -e "v2RayN: ${REALITY_V6_LINK}"
        echo -e "Clash: - {name: Reality_V6, type: vless, server: '${IP6}', port: ${XRAY_PORT}, uuid: ${UUID}, udp: true, tls: true, flow: xtls-rprx-vision, servername: ${DEST_DOMAIN}, network: tcp, reality-opts: {public-key: ${PUBLIC_KEY}, short-id: ${SHORT_ID}}, client-fingerprint: random}"
        echo ""
        {
            echo "[${NOW_TS}] Reality_V6"
            echo "${REALITY_V6_LINK}"
            echo ""
        } >> "${LINK_HISTORY_PATH}"
    fi
    if [ "${USE_HYSTERIA}" -eq 1 ]; then
        HY2_V6_LINK="hysteria2://${UUID}@[${IP6}]:${XRAY_PORT}?sni=${DEST_DOMAIN}&insecure=0&allowInsecure=0&pinSHA256=${CERT_PIN}#Hysteria_V6"
        echo -e "${BLUE}[IPv6 Hysteria2节点信息]${NC}"
        echo -e "${HY2_V6_LINK}"
        echo -e "Clash: - {name: Hysteria_V6, type: hysteria2, server: '${IP6}', port: ${XRAY_PORT}, password: ${UUID}, up: '100 Mbps', down: '200 Mbps', sni: ${DEST_DOMAIN}, skip-cert-verify: false, fingerprint: '${CERT_PIN}', alpn: [h3]}"
        echo ""
        {
            echo "[${NOW_TS}] Hysteria_V6"
            echo "${HY2_V6_LINK}"
            echo ""
        } >> "${LINK_HISTORY_PATH}"
    fi
fi

echo "------------------------------------------------"
echo -e "${GREEN}[管理维护指令]${NC}"
echo -e "1. 实时日志 (查偷流): ${BLUE}tail -f ${LOG_PATH}${NC}"
echo -e "2. 仅更新内核: ${BLUE}sh $0 update${NC}"
echo -e "3. 覆盖安装(刷新密钥): ${BLUE}sh $0${NC}"
echo -e "4. 卸载服务: ${BLUE}sh $0 uninstall${NC}"
echo -e "5. 查看历史节点链接: ${BLUE}sh $0 links${NC}"
echo -e "6. 查看帮助: ${BLUE}sh $0 help${NC}"
echo -e "${GREEN}=============================================================${NC}"
