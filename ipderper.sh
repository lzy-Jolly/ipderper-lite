#!/bin/bash
# this is ipderper.sh

VERSION="1.2.4"
WORKDIR="/etc/ipderperd"
CONFIG_FILE="$WORKDIR/config.json"
CONFIG_TEMPLATE="$WORKDIR/config.jsonc"
DERPER_BIN="$WORKDIR/derper"
BUILD_CERT="$WORKDIR/build_cert.sh"

# 颜色定义
GREEN="\e[32m"; YELLOW="\e[33m"; RED="\e[31m"; BLUE="\e[36m"; RESET="\e[0m"
NC=${NC:-"\033[0m"}

#--------------------------------------------
# 支持大小写的版本查询
#--------------------------------------------
if [ $# -ge 1 ]; then
    arg=$(echo "$1" | tr '[:upper:]' '[:lower:]')
    if [ "$arg" = "-v" ] || [ "$arg" = "--version" ]; then
        echo -e "当前版本 version=\e[33m$VERSION\e[0m"
        exit 0
    fi
fi

#--------------------------------------------
# 状态检测函数（优化版）
#--------------------------------------------
check_status() {
    # ---- 检查 derper 进程 ----
    DERPER_PID=$(ps -eo pid,cmd | grep -F "$DERPER_BIN" | grep -v grep | grep -v "ipderper.sh" | awk '{print $1}')
    if [ -n "$DERPER_PID" ]; then
        DERPER_STATUS="已启动"
        COLOR_D=$GREEN
    else
        DERPER_STATUS="未启动"
        COLOR_D=$YELLOW
    fi

    # ---- 检查 tailscale ----
    if ! command -v tailscale >/dev/null 2>&1; then
        TAILSCALE_STATUS="未安装"
        COLOR_T=$RED
        TAILSCALE_IP=""
    else
        # 检查 tailscaled 是否在运行
        if ! pgrep -x tailscaled >/dev/null 2>&1; then
            TAILSCALE_STATUS="已安装但未启动"
            COLOR_T=$YELLOW
            TAILSCALE_IP=""
        else
            # 获取 tailscale ip (ipv4 优先)
            TAILSCALE_IP=$(tailscale ip -4 2>/dev/null | head -n1)
            if [ -z "$TAILSCALE_IP" ]; then
                # 尝试再次通过 status 获取
                TAILSCALE_IP=$(tailscale status --json 2>/dev/null | jq -r '.Self.TailscaleIPs[]?' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | head -n1)
            fi

            # 检查连接状态
            if tailscale status --json 2>/dev/null | jq -e '.BackendState=="Running"' >/dev/null 2>&1; then
                TAILSCALE_STATUS="已启动并连接"
                COLOR_T=$GREEN
            else
                TAILSCALE_STATUS="已安装但未连接"
                COLOR_T=$YELLOW
            fi
        fi
    fi

    # ---- 输出结果 ----
    echo -e "DERPER 状态: ${COLOR_D}${DERPER_STATUS}${NC}"
    echo -e "Tailscale 状态: ${COLOR_T}${TAILSCALE_STATUS}${NC}"
    [ -n "$TAILSCALE_IP" ] && echo -e "Tailscale IPv4: ${BLUE}${TAILSCALE_IP}${NC}"
}

#--------------------------------------------
# 启动或重启 derper
#--------------------------------------------
start_or_restart_derper() {
    if [ ! -f "$CONFIG_FILE" ]; then
        echo -e "${YELLOW}配置文件不存在，自动生成${RESET}"
        generate_config
    fi

    DERP_ADDR=$(jq -r '.DERP_ADDR' "$CONFIG_FILE")
    DERP_HOST=$(jq -r '.DERP_HOST' "$CONFIG_FILE")
    DERP_HTTP_PORT=$(jq -r '.DERP_HTTP_PORT' "$CONFIG_FILE")
    DERP_CERTS=$(jq -r '.DERP_CERTS' "$CONFIG_FILE")
    DERP_STUN=$(jq -r '.DERP_STUN' "$CONFIG_FILE")
    DERP_VERIFY_CLIENTS=$(jq -r '.DERP_VERIFY_CLIENTS' "$CONFIG_FILE")
    DERP_LOG=$(jq -r '.DERP_LOG' "$CONFIG_FILE")

    mkdir -p "$(dirname "$DERP_LOG")"
    stop_derper >/dev/null 2>&1

    echo -e "${BLUE}生成证书并启动 derper...${RESET}"
    bash "$BUILD_CERT" "$DERP_HOST" "$DERP_CERTS" "$WORKDIR/san.conf"

    nohup "$DERPER_BIN" \
        --hostname="$DERP_HOST" \
        --certmode=manual \
        --certdir="$DERP_CERTS" \
        --stun="$DERP_STUN" \
        --a="$DERP_ADDR" \
        --http-port="$DERP_HTTP_PORT" \
        --verify-clients="$DERP_VERIFY_CLIENTS" \
        >>"$DERP_LOG" 2>&1 &

    echo -e "${GREEN}✅ derper 已启动，日志: $DERP_LOG${RESET}"
}

#--------------------------------------------
# 停止 derper
#--------------------------------------------
stop_derper() {
    pid=$(ps -eo pid,cmd | grep -F "$DERPER_BIN" | grep -v grep | grep -v "ipderper.sh" | awk '{print $1}')
    if [ -n "$pid" ]; then
        kill "$pid"
        echo -e "${GREEN}✅ derper 已停止${RESET}"
    else
        echo -e "${YELLOW}derper 未运行${RESET}"
    fi
}

#--------------------------------------------
# 配置生成
#--------------------------------------------
generate_config() {
    if [ -f "$CONFIG_FILE" ]; then
        cp "$CONFIG_FILE" "$CONFIG_FILE.bak"
        echo -e "${YELLOW}配置文件已备份为 config.json.bak${RESET}"
    fi

    RANDOM_PORT=$((RANDOM%55536 + 10000))
    echo -e "默认随机端口: ${YELLOW}$RANDOM_PORT${RESET}"
    read -r -p "输入端口(回车使用默认): " USER_PORT
    DERP_PORT=${USER_PORT:-$RANDOM_PORT}

    cp "$CONFIG_TEMPLATE" "$CONFIG_FILE"
    sed -i "s/\": 47100\"/\": $DERP_PORT\"/" "$CONFIG_FILE"

    echo -e "${GREEN}✅ 配置文件已生成: $CONFIG_FILE${RESET}"
}

#--------------------------------------------
# 更新脚本
#--------------------------------------------
update_script() {
    sudo sh -c "$(curl -fsSL https://raw.githubusercontent.com/lzy-Jolly/ipderper-lite/main/install_ipderper.sh)"
    echo -e "${GREEN}✅ 脚本已更新${RESET}"
}

#--------------------------------------------
# 说明与免责声明
#--------------------------------------------
show_info() {
    echo "---------------------------------------------------------------"
    echo "脚本来源：https://github.com/lzy-Jolly/ipderper-lite"
    echo "部分代码参考：https://github.com/yangchuansheng/ip_derper"
    echo ""
    echo "⚠️ 免责声明："
    echo "1. 本工具仅用于学习、测试或自用网络环境。"
    echo "2. 使用本工具产生的任何网络安全问题、数据泄露或法律责任由使用者自行承担。"
    echo "3. 本项目为开源软件，遵循 MIT 协议，完全公开。"
    echo "---------------------------------------------------------------"
    read -r -p "按回车返回菜单..."
}

#--------------------------------------------
# 主循环
#--------------------------------------------
while true; do
    check_status
    echo -e "${BLUE}---------欢迎使用脚本 ipderper---------${RESET}"
    echo "1 启动/重启"
    echo "2 停止"
    echo "3 半自动生成配置文件"
    echo "4 更新(重装)"
    echo "5 说明与免责声明"
    echo "0 退出"
    echo "---------------------------------------------------------------"
    echo -e "状态 derper   ${COLOR_D}${DERPER_STATUS}${RESET}"
    echo -e "状态 tailscale ${COLOR_T}${TAILSCALE_STATUS}${RESET}${TAILSCALE_IP:+ IP: ${BLUE}${TAILSCALE_IP}${RESET}}"
    echo "请选择(默认回车刷新检测状态)Ctrl+C退出："
    read -r CHOICE
    case "$CHOICE" in
        1) start_or_restart_derper ;;
        2) stop_derper ;;
        3) generate_config ;;
        4) update_script ;;
        5) show_info ;;
        0) exit 0 ;;
        "") ;; # 刷新
        *) echo "无效选择" ;;
    esac
    sleep 1
done
