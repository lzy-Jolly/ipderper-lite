#!/bin/sh
# this is ipderper.sh

VERSION="1.6.0"
WORKDIR="/etc/ipderperd"
CONFIG_FILE="$WORKDIR/config.json"
CONFIG_TEMPLATE="$WORKDIR/config.jsonc"
DERPER_BIN="$WORKDIR/derper"
BUILD_CERT="$WORKDIR/build_cert.sh"

# 颜色定义
GREEN="\e[32m"; YELLOW="\e[33m"; RED="\e[31m"; BLUE="\e[36m"; RESET="\e[0m"


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
# 状态检测函数
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
}
#--------------------------------------------
# 读取config.json配置
#--------------------------------------------
load_derper_config() {
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
}

#--------------------------------------------
# 生成 derpmap_example.json
#--------------------------------------------
generate_derpmap_example() {
    local derp_port="$1"  # 支持传参，如果未传则尝试从配置读取
    if [ -z "$derp_port" ]; then
        load_derper_config
        derp_port="$DERP_ADDR"
    fi

    # 获取当前日期
    DATE_TAG=$(date '+%y%m%d')
    # 随机 RegionID 900-999
    RegionIDT=$((RANDOM % 100 + 900))
    # 随机 3 个大写字母 RegionCodeT
    RegionCodeT=$(tr -dc 'A-Z' </dev/urandom | head -c3)
    # 当前主机公网 IPv4
    server_ipv4=$(curl -s https://4.ipw.cn)

    # 构建 JSON 文件
    cat >"$WORKDIR/derpmap_example.json" <<EOF
{
  "derpMap": {
    "OmitDefaultRegions": false,
    "Regions": {
      "$RegionIDT": {
        "RegionID": $RegionIDT,
        "RegionCode": "$RegionCodeT",
        "RegionName": "${RegionCodeT}_$DATE_TAG",
        "Nodes": [
          {
            "Name": "${RegionCodeT}_$DATE_TAG",
            "RegionID": $RegionIDT,
            "IPv4": "$server_ipv4",
            "DERPPort": $derp_port,
            "InsecureForTests": true
          }
        ]
      }
    }
  }
}
EOF

    # 输出信息
    echo -e "${BLUE}当前主机公网IP: ${GREEN}$server_ipv4${RESET}"
    echo -e "${BLUE}derp服务端口为: ${GREEN}$derp_port${RED} <-----请注意开放NAT端口!!${RESET}"
    echo -e "${BLUE}请修改 https://login.tailscale.com/admin/acls/file 配置${RESET}"
    echo -e "${GREEN}✅ 已生成案例文件: $WORKDIR/derpmap_example.json${RESET}"
}


#--------------------------------------------
# 启动或重启 derper
#--------------------------------------------
start_or_restart_derper() {
    # 读取config.json配置
    load_derper_config

    # 检测系统类型
    detect_os

    mkdir -p "$(dirname "$DERP_LOG")"
    stop_derper >/dev/null 2>&1

    echo -e "${BLUE}生成证书并启动 derper...${RESET}"
    sh "$BUILD_CERT" "$DERP_HOST" "$DERP_CERTS" "$WORKDIR/san.conf"

    # 根据系统类型选择启动方式
    case "$OS_TYPE" in
        alpine)
            echo -e "${BLUE}使用 Alpine 启动方式 (setsid)...${RESET}"
            setsid "$DERPER_BIN" \
                --a=":$DERP_ADDR" \
                --hostname="$DERP_HOST" \
                --certmode=manual \
                --certdir="$DERP_CERTS" \
                --stun="$DERP_STUN" \
                --http-port="$DERP_HTTP_PORT" \
                --verify-clients="$DERP_VERIFY_CLIENTS" \
                >>"$DERP_LOG" 2>&1 < /dev/null &
            ;;
        debian|ubuntu)
            echo -e "${BLUE}使用 Debian/Ubuntu 启动方式 (nohup)...${RESET}"
            nohup "$DERPER_BIN" \
                --a=":$DERP_ADDR" \
                --hostname="$DERP_HOST" \
                --certmode=manual \
                --certdir="$DERP_CERTS" \
                --stun="$DERP_STUN" \
                --http-port="$DERP_HTTP_PORT" \
                --verify-clients="$DERP_VERIFY_CLIENTS" \
                >>"$DERP_LOG" 2>&1 &
            ;;
        *)
            echo -e "${YELLOW}未知系统类型，使用默认启动方式 (nohup)...${RESET}"
            nohup "$DERPER_BIN" \
                --a=":$DERP_ADDR" \
                --hostname="$DERP_HOST" \
                --certmode=manual \
                --certdir="$DERP_CERTS" \
                --stun="$DERP_STUN" \
                --http-port="$DERP_HTTP_PORT" \
                --verify-clients="$DERP_VERIFY_CLIENTS" \
                >>"$DERP_LOG" 2>&1 &
            ;;
    esac

    # 等待进程启动
    sleep 2
    
    # 检查是否启动成功
    if pgrep -f "$DERPER_BIN" > /dev/null; then
        echo -e "${GREEN}✅ derper 已启动，日志: $DERP_LOG${RESET}"
        echo -e "${BLUE}使用系统: $OS_TYPE | 启动方式: $(case "$OS_TYPE" in alpine) echo "setsid" ;; *) echo "nohup" ;; esac)${RESET}"
    else
        echo -e "${RED}❌ derper 启动失败，请检查日志: $DERP_LOG${RESET}"
        echo -e "${YELLOW}最近日志内容：${RESET}"
        tail -n 10 "$DERP_LOG" 2>/dev/null || echo "日志文件不存在"
    fi

    # 生成 derpmap 示例文件
    generate_derpmap_example "$DERP_ADDR"
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
    # 1️⃣ 备份已有配置
    if [ -f "$CONFIG_FILE" ]; then
        cp "$CONFIG_FILE" "$CONFIG_FILE.bak"
        echo -e "${YELLOW}配置文件已备份为 config.json.bak${RESET}"
    fi

    # 2️⃣ 生成随机端口并让用户选择
    RANDOM_PORT=$((RANDOM % 55536 + 10000))
    echo -e "默认随机端口: ${YELLOW}$RANDOM_PORT${RESET}"
    read -r -p "输入端口(回车使用默认): " USER_PORT
    DERP_PORT=${USER_PORT:-$RANDOM_PORT}

    # 3️⃣ 将模板文件生成 config.json
    cp "$CONFIG_TEMPLATE" "$CONFIG_FILE"
    
    # 删除行内 // 注释，保证 jq 能解析
    sed -i 's|//.*$||' "$CONFIG_FILE"

    # 4️⃣ 使用 jq 修改 DERP_ADDR
    # jq 会自动处理 JSON 注释丢失的问题，如果想保留注释，需要额外处理，这里直接更新值
    jq --arg port "$DERP_PORT" '.DERP_ADDR = ($port|tonumber)' "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"

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
    UTC_TIME=$(date -u '+%y-%m-%d %H:%M')
    BEIJING_TIME=$(date -u -d "$UTC_TIME 8 hour" '+UTC+8 %y-%m-%d--%H:%M')

    echo -e "${BLUE}---------欢迎使用脚本 ipderper---------${RESET}"
    echo "$BEIJING_TIME"
    echo -e "状态 derper   ${COLOR_D}${DERPER_STATUS}${RESET}"
    echo -e "状态 tailscale ${COLOR_T}${TAILSCALE_STATUS}${RESET}${TAILSCALE_IP:+ IP: ${BLUE}${TAILSCALE_IP}${RESET}}"
    echo "---------------------------------------------------------------"
    echo "1 启动/重启"
    echo "2 停止"
    echo "3 半自动生成配置文件"
    echo "4 更新(重装)--测试中"
    echo "5 说明与免责声明"
    echo "6 查看配置 / 生成 derpmap 示例"
    echo "0 退出"
    echo "---------------------------------------------------------------"
    echo "请选择(默认回车刷新检测状态)Ctrl+C退出："
    read -r CHOICE
    case "$CHOICE" in
        1) start_or_restart_derper
           read -n1 -r -p "按任意键返回主菜单..." key
           echo
           ;;
        2) stop_derper
           read -n1 -r -p "按任意键返回主菜单..." key
           echo
           ;;
        3) generate_config
           read -n1 -r -p "按任意键返回主菜单..." key
           echo
           ;;
        4) update_script
           read -n1 -r -p "按任意键返回主菜单..." key
           echo
           ;;
        5) show_info
           read -n1 -r -p "按任意键返回主菜单..." key
           echo
           ;;
        6) generate_derpmap_example
            read -n1 -r -p "按任意键返回主菜单..." key
            echo
            ;;
        0) exit 0 ;;
        "") ;; # 刷新
        *) echo "无效选择" ;;
    esac
done
