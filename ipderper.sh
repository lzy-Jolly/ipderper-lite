#!/bin/sh
# this is ipderper.sh 

VERSION="1.3.0"
WORKDIR="/etc/ipderperd"
CONFIG_FILE="$WORKDIR/config.json"
CONFIG_TEMPLATE="$WORKDIR/config.jsonc"
DERPER_BIN="$WORKDIR/derper"
BUILD_CERT="$WORKDIR/build_cert.sh"

GREEN="\033[32m"; YELLOW="\033[33m"; RED="\033[31m"; BLUE="\033[36m"; RESET="\033[0m"

#--------------------------------------------
# 获取配置值（支持注释的 jsonc）
#--------------------------------------------
get_conf() {
    key="$1"
    # 删除注释行和多余空格，只取匹配的值
    sed 's,//.*,,g' "$CONFIG_FILE" | grep -E "\"$key\"" | head -n1 | \
        sed -E 's/.*: *"?([^",}]+)"?,?/\1/' | tr -d '\r\n'
}

#--------------------------------------------
# 状态检测函数（去掉 jq 依赖）
#--------------------------------------------
check_status() {
    DERPER_PID=$(ps -eo pid,cmd | grep -F "$DERPER_BIN" | grep -v grep | awk '{print $1}')
    if [ -n "$DERPER_PID" ]; then
        DERPER_STATUS="已启动"
        COLOR_D=$GREEN
    else
        DERPER_STATUS="未启动"
        COLOR_D=$YELLOW
    fi

    if ! command -v tailscale >/dev/null 2>&1; then
        TAILSCALE_STATUS="未安装"
        COLOR_T=$RED
        TAILSCALE_IP=""
    elif ! pgrep -x tailscaled >/dev/null 2>&1; then
        TAILSCALE_STATUS="已安装但未启动"
        COLOR_T=$YELLOW
        TAILSCALE_IP=""
    else
        TAILSCALE_IP=$(tailscale ip -4 2>/dev/null | head -n1)
        [ -n "$TAILSCALE_IP" ] && COLOR_T=$GREEN || COLOR_T=$YELLOW
        TAILSCALE_STATUS="已启动"
    fi

    echo -e "DERPER 状态: ${COLOR_D}${DERPER_STATUS}${RESET}"
    echo -e "Tailscale 状态: ${COLOR_T}${TAILSCALE_STATUS}${RESET}"
    [ -n "$TAILSCALE_IP" ] && echo -e "Tailscale IPv4: ${BLUE}${TAILSCALE_IP}${RESET}"
}

#--------------------------------------------
# 启动或重启 derper
#--------------------------------------------
start_or_restart_derper() {
    [ ! -f "$CONFIG_FILE" ] && { echo -e "${YELLOW}配置文件不存在，自动生成${RESET}"; generate_config; }

    DERP_ADDR=$(get_conf "DERP_ADDR")
    DERP_HOST=$(get_conf "DERP_HOST")
    DERP_HTTP_PORT=$(get_conf "DERP_HTTP_PORT")
    DERP_CERTS=$(get_conf "DERP_CERTS")
    DERP_STUN=$(get_conf "DERP_STUN")
    DERP_VERIFY_CLIENTS=$(get_conf "DERP_VERIFY_CLIENTS")
    DERP_LOG=$(get_conf "DERP_LOG")

    [ -z "$DERP_CERTS" ] && DERP_CERTS="$WORKDIR/certs"
    [ -z "$DERP_HOST" ] && DERP_HOST="127.0.0.1"
    [ -z "$DERP_ADDR" ] && DERP_ADDR=":47100"
    [ -z "$DERP_HTTP_PORT" ] && DERP_HTTP_PORT="80"

    mkdir -p "$(dirname "$DERP_LOG")" "$DERP_CERTS"
    stop_derper >/dev/null 2>&1

    echo -e "${BLUE}生成证书并启动 derper...${RESET}"
    sh "$BUILD_CERT" "$DERP_HOST" "$DERP_CERTS" "$WORKDIR/san.conf" || {
        echo -e "${RED}证书生成失败${RESET}"
        return 1
    }

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
    pid=$(ps -eo pid,cmd | grep -F "$DERPER_BIN" | grep -v grep | awk '{print $1}')
    if [ -n "$pid" ]; then
        kill "$pid" 2>/dev/null
        echo -e "${GREEN}✅ derper 已停止${RESET}"
    else
        echo -e "${YELLOW}derper 未运行${RESET}"
    fi
}

#--------------------------------------------
# 配置生成
#--------------------------------------------
generate_config() {
    [ -f "$CONFIG_FILE" ] && cp "$CONFIG_FILE" "$CONFIG_FILE.bak"
    RANDOM_PORT=$((RANDOM%55536 + 10000))
    echo -e "默认随机端口: ${YELLOW}$RANDOM_PORT${RESET}"
    printf "输入端口(回车使用默认): "
    read -r USER_PORT
    DERP_PORT=${USER_PORT:-$RANDOM_PORT}
    mkdir -p "$WORKDIR"
    sed "s/: 47100/: $DERP_PORT/" "$CONFIG_TEMPLATE" | sed 's,//.*,,g' >"$CONFIG_FILE"
    echo -e "${GREEN}✅ 配置文件已生成: $CONFIG_FILE${RESET}"
}

#--------------------------------------------
# 更新脚本
#--------------------------------------------
update_script() {
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/lzy-Jolly/ipderper-lite/main/install_ipderper.sh)"
    echo -e "${GREEN}✅ 脚本已更新${RESET}"
}

#--------------------------------------------
# 主循环
#--------------------------------------------
while true; do
    check_status
    echo ""
    echo -e "${BLUE}--------- ipderper 控制面板 ---------${RESET}"
    echo "1 启动/重启"
    echo "2 停止"
    echo "3 半自动生成配置文件"
    echo "4 更新(重装)"
    echo "0 退出"
    echo "------------------------------------"
    printf "请选择(回车刷新 Ctrl+C退出): "
    read -r CHOICE
    case "$CHOICE" in
        1) start_or_restart_derper ;;
        2) stop_derper ;;
        3) generate_config ;;
        4) update_script ;;
        0) exit 0 ;;
        "") ;;
        *) echo "无效选择" ;;
    esac
    sleep 1
done
