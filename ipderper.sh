#!/bin/bash
# this is ipderper.sh

# 版本
VERSION="1.2.0"
# ipderper.sh
# 交互式管理 derper + tailscale
# 工作目录：/etc/ipderperd
# 功能：
# 1 启动/重启 derper
# 2 停止 derper
# 3 半自动生成配置文件
# 4 更新(重装) ipderper
# 5 说明与免责声明
# 0 退出

#------------------------------
# 支持大小写的版本查询
#------------------------------
if [ $# -ge 1 ]; then
    arg=$(echo "$1" | tr '[:upper:]' '[:lower:]')
    if [ "$arg" = "-v" ] || [ "$arg" = "--version" ]; then
        echo -e "当前版本 version=\e[33m$VERSION\e[0m"
        exit 0
    fi
fi

#------------------------------
# 工作目录及文件
#------------------------------
WORKDIR="/etc/ipderperd"
CONFIG_FILE="$WORKDIR/config.json"
CONFIG_TEMPLATE="$WORKDIR/config.jsonc"
DERPER_BIN="$WORKDIR/derper"
BUILD_CERT="$WORKDIR/build_cert.sh"

# 颜色定义
GREEN="\e[32m"
YELLOW="\e[33m"
RED="\e[31m"
BLUE="\e[36m"
RESET="\e[0m"

#--------------------------------------------
# 状态检测函数
#--------------------------------------------

check_status() {
    # derper 状态检测
    if [ -f "$DERPER_BIN" ]; then
        OS_TYPE=$(awk -F= '/^ID=/{print $2}' /etc/os-release | tr -d '"')
        if [ "$OS_TYPE" = "alpine" ]; then
            PS_CMD="ps -e"
        else
            PS_CMD="ps -ef"
        fi

        # 排除当前脚本进程
        DERPER_PID=$($PS_CMD | grep "[d]erper" | grep -v "[i]pderper.sh" | awk '{print $1}')
        if [ -n "$DERPER_PID" ]; then
            DERPER_STATUS="已启动"
            COLOR_D=$GREEN
        else
            DERPER_STATUS="未启动"
            COLOR_D=$YELLOW
        fi
    else
        DERPER_STATUS="未安装"
        COLOR_D=$RED
    fi

    # tailscale 状态检测
    
    if command -v tailscale >/dev/null 2>&1; then
        # tailscale 是否在运行
        TAILSCALE_PID=$($PS_CMD | grep "[t]ailscaled" | awk '{print $1}')
        if [ -n "$TAILSCALE_PID" ]; then
            TAILSCALE_STATUS="已启动"
            # 获取第一个 IPv4 地址
            TAILSCALE_IP=$(tailscale ip 2>/dev/null | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -n1)
            COLOR_T=$GREEN
        else
            TAILSCALE_STATUS="未启动"
            TAILSCALE_IP=""
            COLOR_T=$YELLOW
        fi
    else
        TAILSCALE_STATUS="未安装"
        TAILSCALE_IP=""
        COLOR_T=$RED
    fi
}

#--------------------------------------------
# 启动或重启 derper
#--------------------------------------------
start_or_restart_derper() {
    if [ ! -f "$CONFIG_FILE" ]; then
        echo -e "${YELLOW}配置文件不存在，自动生成${RESET}"
        generate_config
    fi

    # 读取配置
    DERP_ADDR=$(jq -r '.DERP_ADDR' "$CONFIG_FILE")
    DERP_HOST=$(jq -r '.DERP_HOST' "$CONFIG_FILE")
    DERP_HTTP_PORT=$(jq -r '.DERP_HTTP_PORT' "$CONFIG_FILE")
    DERP_CERTS=$(jq -r '.DERP_CERTS' "$CONFIG_FILE")
    DERP_STUN=$(jq -r '.DERP_STUN' "$CONFIG_FILE")
    DERP_VERIFY_CLIENTS=$(jq -r '.DERP_VERIFY_CLIENTS' "$CONFIG_FILE")
    DERP_SOCK=$(jq -r '.DERP_SOCK' "$CONFIG_FILE")
    DERP_LOG=$(jq -r '.DERP_LOG' "$CONFIG_FILE")

    mkdir -p "$(dirname "$DERP_LOG")"

    # 停止已有进程
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
    pid=$(pgrep -f "$DERPER_BIN")
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

    # 使用 sed 替换 47100 为新的端口
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
# 显示说明与免责声明
#--------------------------------------------
show_info() {
    echo "---------------------------------------------------------------"
    echo "脚本来源：https://github.com/lzy-Jolly/ipderper-lite"
    echo "部分代码参考：https://github.com/yangchuansheng/ip_derper"
    echo ""
    echo "⚠️ 免责声明："
    echo "1. 本工具仅用于学习、测试或自用网络环境。"
    echo "2. 使用本工具产生的任何网络安全问题、数据泄露或法律责任由使用者自行承担。"
    echo "3. 本项目为开源软件，遵循 MIT 协议，完全公开："
    echo "   - 允许使用、复制、修改、合并、发布、分发、再授权和销售软件副本。"
    echo "   - 使用时请保留原作者版权声明和本许可声明。"
    echo "---------------------------------------------------------------"
    read -r -p "按回车返回菜单..."
}

#--------------------------------------------
# 主循环
#--------------------------------------------
while true; do
    check_status
    clear
    echo -e "${BLUE}---------欢迎使用脚本 ipderper---------${RESET}"
    echo "1 启动/重启"
    echo "2 停止"
    echo "3 半自动生成配置文件"
    echo "4 更新(重装)"
    echo "5 说明与免责声明"
    echo "0 退出"
    echo "---------------------------------------------------------------"

    echo -e "状态 derper  ${COLOR_D}${DERPER_STATUS}${RESET}"
    echo -e "状态 tailscale ${COLOR_T}${TAILSCALE_STATUS}${RESET} IP: ${TAILSCALE_IP}"

    if [ "$DERPER_STATUS" = "已启动" ] && [ "$TAILSCALE_STATUS" = "已启动" ]; then
        echo "PS: 请选择(默认回车刷新检测状态)Ctrl+C退出："
    else
        echo "PS:"
        [ "$DERPER_STATUS" = "未安装" ] && echo "    ipderper程序包缺失，重新下载-->5查看说明"
        [ "$TAILSCALE_STATUS" = "未安装" ] && echo "    tailscale未安装，curl -fsSL https://tailscale.com/install.sh | sh"
    fi

    read -r CHOICE
    case "$CHOICE" in
        1) start_or_restart_derper ;;
        2) stop_derper ;;
        3) generate_config ;;
        4) update_script ;;
        5) show_info ;;
        0) exit 0 ;;
        "") ;; # 回车刷新状态
        *) echo "无效选择" ;;
    esac
    sleep 1
done
