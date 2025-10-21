#!/bin/sh
# this is ipderper.sh

VERSION="1.7.0"
WORKDIR="/etc/ipderperd"
CONFIG_FILE="$WORKDIR/config.json"
CONFIG_TEMPLATE="$WORKDIR/config.jsonc"
DERPER_BIN="$WORKDIR/derper"
BUILD_CERT="$WORKDIR/build_cert.sh"
PID_FILE="$WORKDIR/derper.pid"

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
# 增强的系统类型和初始化系统检测
#--------------------------------------------
detect_system() {
    # 检测操作系统类型
    if [ -f /etc/os-release ]; then
        OS_TYPE=$(awk -F= '/^ID=/{print $2}' /etc/os-release | tr -d '"' | tr '[:upper:]' '[:lower:]')
    else
        OS_TYPE="unknown"
    fi
    
    # 检测初始化系统
    INIT_SYSTEM="unknown"
    if command -v systemctl >/dev/null 2>&1 && systemctl --version >/dev/null 2>&1; then
        INIT_SYSTEM="systemd"
    elif [ -d /run/openrc ]; then
        INIT_SYSTEM="openrc"
    elif [ -f /sbin/init ] && /sbin/init --version 2>/dev/null | grep -q upstart; then
        INIT_SYSTEM="upstart"
    fi
    
    # 调试信息
    echo -e "${BLUE}检测到系统: $OS_TYPE, 初始化系统: $INIT_SYSTEM${RESET}"
    
    # 支持的系统列表
    SUPPORTED_OS="alpine debian ubuntu centos rhel fedora"
    
    case "$SUPPORTED_OS" in
        *"$OS_TYPE"*) 
            echo -e "${GREEN}✅ 系统类型已识别: $OS_TYPE${RESET}"
            ;;
        *)
            echo -e "${YELLOW}⚠️  未知系统类型: $OS_TYPE${RESET}"
            ;;
    esac
    
    case "$INIT_SYSTEM" in
        systemd|openrc)
            echo -e "${GREEN}✅ 初始化系统已识别: $INIT_SYSTEM${RESET}"
            ;;
        *)
            echo -e "${YELLOW}⚠️  未知初始化系统: $INIT_SYSTEM，使用进程方式${RESET}"
            ;;
    esac
}

#--------------------------------------------
# 使用 systemd 启动
#--------------------------------------------
start_with_systemd() {
    echo -e "${BLUE}使用 systemd 启动 derper...${RESET}"
    
    # 创建 systemd 服务文件
    cat > /tmp/ipderper.service << EOF
[Unit]
Description=IPDerper DERP Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$WORKDIR
ExecStart=$DERPER_BIN \\
    --a=:$DERP_ADDR \\
    --hostname=$DERP_HOST \\
    --certmode=manual \\
    --certdir=$DERP_CERTS \\
    --stun=$DERP_STUN \\
    --http-port=$DERP_HTTP_PORT \\
    --verify-clients=$DERP_VERIFY_CLIENTS
Restart=always
RestartSec=5
StandardOutput=append:$DERP_LOG
StandardError=append:$DERP_LOG

[Install]
WantedBy=multi-user.target
EOF

    # 安装并启动服务
    sudo cp /tmp/ipderper.service /etc/systemd/system/
    sudo systemctl daemon-reload
    sudo systemctl enable ipderper.service
    sudo systemctl start ipderper.service
    
    # 检查启动状态
    local start_time=$(date +%s)
    local timeout=10
    
    while [ $(($(date +%s) - start_time)) -lt $timeout ]; do
        if systemctl is-active --quiet ipderper.service; then
            local derper_pid=$(systemctl show --property=MainPID ipderper.service | cut -d= -f2)
            echo -e "${GREEN}✅ derper 已通过 systemd 启动 (PID: $derper_pid)${RESET}"
            echo "$derper_pid" > "$PID_FILE"
            return 0
        fi
        sleep 1
    done
    
    echo -e "${RED}❌ systemd 启动失败${RESET}"
    sudo systemctl status ipderper.service --no-pager
    return 1
}

#--------------------------------------------
# 使用 OpenRC 启动 (Alpine)
#--------------------------------------------
start_with_openrc() {
    echo -e "${BLUE}使用 OpenRC 启动 derper...${RESET}"
    
    # 创建 OpenRC init 脚本
    cat > /tmp/ipderper << EOF
#!/sbin/openrc-run

name="IPDerper DERP Server"
description="Tailscale DERP server for IPDerper"
command="$DERPER_BIN"
command_args="--a=:$DERP_ADDR --hostname=$DERP_HOST --certmode=manual --certdir=$DERP_CERTS --stun=$DERP_STUN --http-port=$DERP_HTTP_PORT --verify-clients=$DERP_VERIFY_CLIENTS"
command_user="root:root"
pidfile="/var/run/ipderper.pid"
output_log="$DERP_LOG"
error_log="$DERP_LOG"

depend() {
    need net
    after firewall
}

start_pre() {
    checkpath --directory --owner \$command_user \$(dirname \$output_log)
}

start_post() {
    echo "IPDerper DERP server started"
}

stop_post() {
    echo "IPDerper DERP server stopped"
}
EOF

    # 安装并启动服务
    sudo cp /tmp/ipderper /etc/init.d/
    sudo chmod +x /etc/init.d/ipderper
    sudo rc-update add ipderper default
    sudo /etc/init.d/ipderper start
    
    # 检查启动状态
    local start_time=$(date +%s)
    local timeout=10
    
    while [ $(($(date +%s) - start_time)) -lt $timeout ]; do
        if sudo /etc/init.d/ipderper status >/dev/null 2>&1; then
            local derper_pid=$(pgrep -f "$(basename "$DERPER_BIN")")
            echo -e "${GREEN}✅ derper 已通过 OpenRC 启动 (PID: $derper_pid)${RESET}"
            echo "$derper_pid" > "$PID_FILE"
            return 0
        fi
        sleep 1
    done
    
    echo -e "${RED}❌ OpenRC 启动失败${RESET}"
    sudo /etc/init.d/ipderper status
    return 1
}

#--------------------------------------------
# 使用进程方式启动 (回退方案)
#--------------------------------------------
start_with_process() {
    echo -e "${BLUE}使用进程方式启动 derper...${RESET}"
    
    # 使用 nohup 启动并完全分离进程
    nohup "$DERPER_BIN" \
        --a=":$DERP_ADDR" \
        --hostname="$DERP_HOST" \
        --certmode=manual \
        --certdir="$DERP_CERTS" \
        --stun="$DERP_STUN" \
        --http-port="$DERP_HTTP_PORT" \
        --verify-clients="$DERP_VERIFY_CLIENTS" \
        >>"$DERP_LOG" 2>&1 &
    
    local derper_pid=$!
    sleep 2
    
    if kill -0 "$derper_pid" 2>/dev/null; then
        echo "$derper_pid" > "$PID_FILE"
        echo -e "${GREEN}✅ derper 已通过进程方式启动 (PID: $derper_pid)${RESET}"
        return 0
    else
        echo -e "${RED}❌ 进程启动失败${RESET}"
        return 1
    fi
}

#--------------------------------------------
# 确保日志目录存在
#--------------------------------------------
ensure_log_directory() {
    local log_dir=$(dirname "$DERP_LOG")
    if [ ! -d "$log_dir" ]; then
        mkdir -p "$log_dir" || {
            echo -e "${RED}❌ 无法创建日志目录: $log_dir${RESET}"
            return 1
        }
    fi
    # 确保日志文件存在且可写
    touch "$DERP_LOG" 2>/dev/null || {
        echo -e "${RED}❌ 无法写入日志文件: $DERP_LOG${RESET}"
        return 1
    }
}

#--------------------------------------------
# 精确的 derper 状态检查
#--------------------------------------------
check_derper_status() {
    local pid_to_check=""
    
    # 先检查 PID 文件
    if [ -f "$PID_FILE" ]; then
        pid_to_check=$(cat "$PID_FILE")
        if [ -n "$pid_to_check" ] && kill -0 "$pid_to_check" 2>/dev/null; then
            echo "$pid_to_check"
            return 0
        else
            rm -f "$PID_FILE"
        fi
    fi
    
    # 精确查找 derper 进程
    pid_to_check=$(ps -eo pid,args | grep -F "$DERPER_BIN" | grep -v grep | grep -v "ipderper.sh" | awk '{print $1}' | head -1)
    
    if [ -n "$pid_to_check" ]; then
        # 验证进程确实是 derper
        if [ -f "/proc/$pid_to_check/cmdline" ]; then
            local cmdline=$(cat "/proc/$pid_to_check/cmdline" 2>/dev/null | tr -d '\0')
            if echo "$cmdline" | grep -q "derper"; then
                echo "$pid_to_check" > "$PID_FILE"
                echo "$pid_to_check"
                return 0
            fi
        fi
    fi
    
    echo ""
    return 1
}

#--------------------------------------------
# 状态检测函数
#--------------------------------------------
check_status() {
    # ---- 检查 derper 状态 ----
    local derper_pid=$(check_derper_status)
    if [ -n "$derper_pid" ]; then
        DERPER_STATUS="已启动"
        COLOR_D=$GREEN
        DERPER_PID=$derper_pid
    else
        DERPER_STATUS="未启动"
        COLOR_D=$YELLOW
        DERPER_PID=""
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
    local derp_port="$1"
    if [ -z "$derp_port" ]; then
        load_derper_config
        derp_port="$DERP_ADDR"
    fi

    DATE_TAG=$(date '+%y%m%d')
    RegionIDT=$((RANDOM % 100 + 900))
    RegionCodeT=$(tr -dc 'A-Z' </dev/urandom | head -c3)
    server_ipv4=$(curl -s https://4.ipw.cn)

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

    # 检测系统类型和初始化系统
    detect_system

    # 确保日志目录和文件
    if ! ensure_log_directory; then
        echo -e "${RED}❌ 日志初始化失败，无法启动 derper${RESET}"
        return 1
    fi

    # 停止运行中的 derper
    stop_derper >/dev/null 2>&1
    sleep 2

    echo -e "${BLUE}生成证书并启动 derper...${RESET}"
    sh "$BUILD_CERT" "$DERP_HOST" "$DERP_CERTS" "$WORKDIR/san.conf"

    # 记录启动时间
    echo "=== derper 启动于 $(date) ===" >> "$DERP_LOG"

    # 根据初始化系统选择启动方式
    case "$INIT_SYSTEM" in
        systemd)
            start_with_systemd
            ;;
        openrc)
            start_with_openrc
            ;;
        *)
            echo -e "${YELLOW}⚠️  使用进程方式启动${RESET}"
            start_with_process
            ;;
    esac

    # 验证启动结果
    local start_time=$(date +%s)
    local timeout=15
    
    while [ $(($(date +%s) - start_time)) -lt $timeout ]; do
        local running_pid=$(check_derper_status)
        if [ -n "$running_pid" ]; then
            echo -e "${GREEN}✅ derper 运行稳定 (PID: $running_pid)${RESET}"
            echo -e "${BLUE}日志文件: $DERP_LOG${RESET}"
            echo -e "${BLUE}启动方式: $INIT_SYSTEM${RESET}"
            
            # 显示最近日志
            echo -e "${YELLOW}最近日志:${RESET}"
            tail -n 5 "$DERP_LOG"
            break
        fi
        sleep 1
    done

    if [ $(($(date +%s) - start_time)) -ge $timeout ]; then
        echo -e "${RED}❌ derper 启动失败${RESET}"
        echo -e "${YELLOW}请检查日志: $DERP_LOG${RESET}"
        tail -n 20 "$DERP_LOG" 2>/dev/null
    fi

    # 生成 derpmap 示例文件
    generate_derpmap_example "$DERP_ADDR"
}

#--------------------------------------------
# 停止 derper
#--------------------------------------------
stop_derper() {
    # 根据初始化系统选择停止方式
    case "$INIT_SYSTEM" in
        systemd)
            if systemctl is-active --quiet ipderper.service 2>/dev/null; then
                sudo systemctl stop ipderper.service
                sudo systemctl disable ipderper.service
                echo -e "${GREEN}✅ derper 已停止 (systemd)${RESET}"
                rm -f "$PID_FILE"
                return 0
            fi
            ;;
        openrc)
            if [ -f /etc/init.d/ipderper ] && /etc/init.d/ipderper status >/dev/null 2>&1; then
                sudo /etc/init.d/ipderper stop
                sudo rc-update del ipderper default
                echo -e "${GREEN}✅ derper 已停止 (OpenRC)${RESET}"
                rm -f "$PID_FILE"
                return 0
            fi
            ;;
    esac
    
    # 回退到进程方式停止
    local pid_to_kill=$(check_derper_status)
    if [ -n "$pid_to_kill" ]; then
        kill "$pid_to_kill"
        echo -e "${GREEN}✅ derper 已停止 (PID: $pid_to_kill)${RESET}"
        rm -f "$PID_FILE"
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

    RANDOM_PORT=$(od -An -N2 -i /dev/urandom | awk -v min=10000 -v max=65535 '{print ($1 % (max - min + 1)) + min}')
    echo -e "默认随机端口: ${YELLOW}$RANDOM_PORT${RESET}"
    read -r -p "输入端口(回车使用默认): " USER_PORT
    DERP_PORT=${USER_PORT:-$RANDOM_PORT}

    cp "$CONFIG_TEMPLATE" "$CONFIG_FILE"
    sed -i 's|//.*$||' "$CONFIG_FILE"
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
           printf "按Enter返回主菜单..." 
           read -r key
           echo
           ;;
        2) stop_derper
           printf "按Enter返回主菜单..." 
           read -r key
           echo
           ;;
        3) generate_config
           printf "按Enter返回主菜单..."
           read -r key 
           echo
           ;;
        4) update_script
           printf "按Enter返回主菜单..."
           read -r key
           echo
           ;;
        5) show_info
           printf "按Enter返回主菜单..."
           read -r key 
           echo
           ;;
        6) generate_derpmap_example
            printf "按Enter返回主菜单..."
            read -r key
            echo
            ;;
        0) exit 0 ;;
        "") ;; # 刷新
        *) echo "无效选择" ;;
    esac
done
