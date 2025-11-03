#!/bin/sh
# this is ipderper.sh

VERSION="1.9.1"
WORKDIR="/etc/ipderperd"
CONFIG_FILE="$WORKDIR/config.json"
CONFIG_TEMPLATE="$WORKDIR/app/config.jsonc"
DERPER_BIN="$WORKDIR/app/derper"
BUILD_CERT="$WORKDIR/app/build_cert.sh"

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
    
    # 检测初始化系统 - 优先使用 systemd
    INIT_SYSTEM="unknown"
    if command -v systemctl >/dev/null 2>&1 && systemctl --version >/dev/null 2>&1; then
        INIT_SYSTEM="systemd"
    elif [ -d /run/openrc ]; then
        INIT_SYSTEM="openrc"
    fi
    
    # 合并显示系统信息
    SUPPORTED_OS="alpine debian ubuntu centos rhel fedora"
    
    if echo "$SUPPORTED_OS" | grep -q "$OS_TYPE"; then
        echo -e "${GREEN}✅ 系统类型: $OS_TYPE, 初始化系统: $INIT_SYSTEM${RESET}"
    else
        echo -e "${YELLOW}⚠️  系统类型: $OS_TYPE, 初始化系统: $INIT_SYSTEM${RESET}"
    fi
}

#--------------------------------------------
# 使用 systemd 启动
#--------------------------------------------
start_with_systemd() {
    echo -e "${BLUE}使用 systemd 启动 derper...${RESET}"
    
    # 设置日志管理
    setup_log_management
    
    # 创建 systemd 服务文件
    cat > "$WORKDIR/selfipderperd.service" << EOF
[Unit]
Description=Self IP Derper DERP Server
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

# 设置进程名
ExecStartPre=/bin/bash -c 'echo "启动 selfipderperd 服务..."'
ExecReload=/bin/kill -HUP \$MAINPID

# 进程名标识
SyslogIdentifier=selfipderperd

[Install]
WantedBy=multi-user.target
EOF

    # 安装并启动服务
    sudo cp "$WORKDIR/selfipderperd.service" /etc/systemd/system/
    sudo systemctl daemon-reload
    sudo systemctl enable selfipderperd.service
    sudo systemctl start selfipderperd.service
    
    # 检查启动状态
    local start_time=$(date +%s)
    local timeout=10
    
    while [ $(($(date +%s) - start_time)) -lt $timeout ]; do
        if systemctl is-active --quiet selfipderperd.service; then
            local derper_pid=$(systemctl show --property=MainPID selfipderperd.service | cut -d= -f2)
            echo -e "${GREEN}✅ derper 已通过 systemd 启动 (服务名: selfipderperd, PID: $derper_pid)${RESET}"
            return 0
        fi
        sleep 1
    done
    
    echo -e "${RED}❌ systemd 启动失败${RESET}"
    sudo systemctl status selfipderperd.service --no-pager
    return 1
}

#--------------------------------------------
# 日志管理设置 (systemd 专用)
#--------------------------------------------
setup_log_management() {
    # 只在 systemd 系统上设置 logrotate
    if [ "$INIT_SYSTEM" != "systemd" ]; then
        echo -e "${YELLOW}⚠️  非 systemd 系统，跳过 logrotate 设置${RESET}"
        return 0
    fi
    
    local logrotate_config="/etc/logrotate.d/selfipderperd"
    
    # 创建 logrotate 配置
    cat > "$logrotate_config" << EOF
$WORKDIR/logs/derper.log {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    notifempty
    copytruncate
    maxsize 32M
}
EOF
    
    # 设置权限
    chmod 644 "$logrotate_config"
    
    echo -e "${GREEN}✅ systemd 日志管理已配置${RESET}"
    echo -e "   位置: $logrotate_config"
    echo -e "   保留: 7份, 单文件: 32MB"
}

#--------------------------------------------
# 使用 OpenRC 启动 (Alpine) - 优化版本
#--------------------------------------------
start_with_openrc() {
    echo -e "${BLUE}使用 OpenRC 启动 derper...${RESET}"
    
    # 创建 OpenRC init 脚本临时文件
    local init_script="$WORKDIR/selfipderperd"
    
    cat > "$init_script" << EOF
#!/sbin/openrc-run

name="Self IP Derper DERP Server"
description="Self hosted Tailscale DERP server"
command="$DERPER_BIN"
command_args="--a=:$DERP_ADDR --hostname=$DERP_HOST --certmode=manual --certdir=$DERP_CERTS --stun=$DERP_STUN --http-port=$DERP_HTTP_PORT --verify-clients=$DERP_VERIFY_CLIENTS"
command_background=true
output_log="$DERP_LOG"
error_log="$DERP_LOG"
pidfile="/var/run/selfipderperd.pid"

depend() {
    need net
    after firewall
}

start_pre() {
    checkpath --directory --owner \${command_user:-root:root} \$(dirname \$output_log) || return 1
    return 0
}

start_post() {
    echo "Self IP Derper DERP server started"
}

stop_post() {
    echo "Self IP Derper DERP server stopped"
    rm -f "\$pidfile"
}

reload() {
    if [ -f "\$pidfile" ]; then
        local pid=\$(cat "\$pidfile")
        if [ -n "\$pid" ]; then
            kill -HUP "\$pid"
            eend \$? "Failed to reload selfipderperd"
        else
            eend 1 "PID file exists but is empty"
        fi
    else
        eend 1 "PID file does not exist"
    fi
}
EOF

    # 安装并启动服务
    sudo cp "$init_script" /etc/init.d/selfipderperd
    sudo chmod +x /etc/init.d/selfipderperd
    sudo rc-update add selfipderperd default
    sudo /etc/init.d/selfipderperd start
    
    # 检查启动状态
    local start_time=$(date +%s)
    local timeout=10
    
    while [ $(($(date +%s) - start_time)) -lt $timeout ]; do
        if sudo rc-service selfipderperd status >/dev/null 2>&1; then
            local derper_pid=$(sudo rc-service selfipderperd status 2>/dev/null | grep -o "pid [0-9]*" | awk '{print $2}' | head -1)
            echo -e "${GREEN}✅ derper 已通过 OpenRC 启动 (服务名: selfipderperd, PID: $derper_pid)${RESET}"
            return 0
        fi
        sleep 1
    done
    
    echo -e "${RED}❌ OpenRC 启动失败${RESET}"
    sudo rc-service selfipderperd status
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
        echo -e "${GREEN}✅ derper 已通过进程方式启动 (PID: $derper_pid)${RESET}"
        return 0
    else
        echo -e "${RED}❌ 进程启动失败${RESET}"
        return 1
    fi
}

#--------------------------------------------
# 统一状态检查函数 - 优化 Alpine 支持
#--------------------------------------------
status_checker() {
    local os_type="$1"
    
    # 如果不带参数，执行完整状态检查
    if [ $# -eq 0 ]; then
        # ---- 检查 derper 状态 ----
        local derper_status=$(status_checker "$OS_TYPE")
        case "$derper_status" in
            "running")
                DERPER_STATUS="已启动"
                COLOR_D=$GREEN
                if [ "$INIT_SYSTEM" = "systemd" ]; then
                    DERPER_PID=$(systemctl show --property=MainPID selfipderperd.service 2>/dev/null | cut -d= -f2)
                elif [ "$INIT_SYSTEM" = "openrc" ]; then
                    DERPER_PID=$(sudo rc-service selfipderperd status 2>/dev/null | grep -o "pid [0-9]*" | awk '{print $2}' | head -1)
                else
                    DERPER_PID=""
                fi
                ;;
            "failed")
                DERPER_STATUS="启动失败"
                COLOR_D=$RED
                DERPER_PID=""
                ;;
            *)
                DERPER_STATUS="未启动"
                COLOR_D=$YELLOW
                DERPER_PID=""
                ;;
        esac

        # ---- 检查 tailscale 状态 ----
        if ! command -v tailscale >/dev/null 2>&1; then
            TAILSCALE_STATUS="未安装，不支持docker安装"
            COLOR_T=$RED
            TAILSCALE_IP=""
        else
            # 检查 tailscaled 是否在运行（兼容 Alpine / BusyBox）
            if ! pgrep -x tailscaled >/dev/null 2>&1 && ! pidof tailscaled >/dev/null 2>&1; then
                TAILSCALE_STATUS="未启动，tailscale up启动"
                COLOR_T=$RED
                TAILSCALE_IP=""
            else
                # 获取 BackendState
                BACKEND_STATE=$(tailscale status --json 2>/dev/null | jq -r '.BackendState' 2>/dev/null || echo "Stopped")

                # 根据状态映射
                case "$BACKEND_STATE" in
                    Running)
                        TAILSCALE_STATUS="已启动"
                        COLOR_T=$GREEN
                        ;;
                    NeedsLogin)
                        TAILSCALE_STATUS="未登录 tailscale login"
                        COLOR_T=$YELLOW
                        ;;
                    Stopped|*)
                        TAILSCALE_STATUS="未启动，tailscale up启动"
                        COLOR_T=$RED
                        ;;
                esac

                # 获取 tailscale IPv4 地址（优先 IPv4）
                if [ "$BACKEND_STATE" = "Running" ]; then
                TAILSCALE_IP=$(tailscale ip -4 2>/dev/null | head -n1)
                if [ -z "$TAILSCALE_IP" ]; then
                        TAILSCALE_IP=$(tailscale status --json 2>/dev/null \
                            | jq -r '.Self.TailscaleIPs[]?' \
                            | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' \
                            | head -n1)
                fi
                else
                    TAILSCALE_IP="无法正确获取tailnet IP" 
                    echo -e "${YELLOW}⚠️ 请稍等tailscale ip手动确认${RESET}"
                fi
            fi
        fi
        
        return 0
    fi
    
    # 带参数时，只检查 derper 服务状态
    local result=""
    
    case "$os_type" in
        alpine)
            # OpenRC 系统状态检查
            if command -v rc-status >/dev/null 2>&1; then
                if rc-status | grep -q selfipderperd && sudo rc-service selfipderperd status >/dev/null 2>&1; then
                    result="running"
                else
                    result="stopped"
                fi
            else
                # 回退到进程检查
                if pgrep -f "selfipderperd" >/dev/null 2>&1 || pgrep -f "$(basename "$DERPER_BIN")" >/dev/null 2>&1; then
                    result="running"
                else
                    result="stopped"
                fi
            fi
            ;;
        debian|ubuntu|centos|rhel|fedora|*)
            # systemd 系统状态检查
            if systemctl is-active --quiet selfipderperd.service 2>/dev/null; then
                result="running"
            elif systemctl is-failed --quiet selfipderperd.service 2>/dev/null; then
                result="failed"
            else
                result="stopped"
            fi
            ;;
    esac
    
    echo "$result"
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

    # 停止运行中的 derper
    exit_derper >/dev/null 2>&1
    sleep 2

    echo -e "${BLUE}生成证书并启动 derper...${RESET}"
    sh "$BUILD_CERT" "$DERP_HOST" "$DERP_CERTS" "$WORKDIR/app/san.conf"

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
        local status=$(status_checker "$OS_TYPE")
        if [ "$status" = "running" ]; then
            local derper_pid=""
            if [ "$INIT_SYSTEM" = "systemd" ]; then
                derper_pid=$(systemctl show --property=MainPID selfipderperd.service 2>/dev/null | cut -d= -f2)
            elif [ "$INIT_SYSTEM" = "openrc" ]; then
                derper_pid=$(sudo rc-service selfipderperd status 2>/dev/null | grep -o "pid [0-9]*" | awk '{print $2}' | head -1)
            fi
            
            echo -e "${GREEN}✅ derper 运行稳定${RESET}"
            [ -n "$derper_pid" ] && [ "$derper_pid" != "0" ] && echo -e "${BLUE}PID: $derper_pid${RESET}"
            echo -e "${BLUE}日志文件: $DERP_LOG${RESET}"
            echo -e "${BLUE}启动方式: $INIT_SYSTEM${RESET}"
            
            # 显示最近日志
            echo -e "${YELLOW}最近日志:${RESET}"
            tail -n 8 "$DERP_LOG"
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
# 停止 derper - 优化 Alpine 支持
#--------------------------------------------
exit_derper() {
    local max_retries=3
    local retry_count=0
    local stop_success=false
    
    # 根据初始化系统选择停止方式
    case "$INIT_SYSTEM" in
        systemd)
            if systemctl is-active --quiet selfipderperd.service 2>/dev/null; then
                echo -e "${BLUE}使用 systemd 停止 derper...${RESET}"
                sudo systemctl stop selfipderperd
                sudo systemctl disable selfipderperd
                
                # 等待进程完全停止
                while [ $retry_count -lt $max_retries ]; do
                    if ! systemctl is-active --quiet selfipderperd.service 2>/dev/null; then
                        stop_success=true
                        break
                    fi
                    retry_count=$((retry_count + 1))
                    sleep 2
                done
                
                # 清理残留服务文件
                sudo rm -f /etc/systemd/system/selfipderperd.service
                sudo systemctl daemon-reload
                sudo systemctl reset-failed selfipderperd.service 2>/dev/null || true
            fi
            ;;
        openrc)
            if command -v rc-status >/dev/null 2>&1 && rc-status | grep -q selfipderperd; then
                echo -e "${BLUE}使用 OpenRC 停止 derper...${RESET}"
                sudo rc-service selfipderperd stop
                sudo rc-update del selfipderperd default
                
                # 删除 init 脚本（临时文件自动清理）
                sudo rm -f /etc/init.d/selfipderperd
                
                stop_success=true
            fi
            ;;
    esac
    
    # 检查是否还有 derper 进程在运行
    local pids=""
    if command -v ps >/dev/null 2>&1; then
        if ps -eo pid,args >/dev/null 2>&1; then
            pids=$(ps -eo pid,args 2>/dev/null | grep -F "$DERPER_BIN" | grep -v grep | grep -v "ipderper.sh" | awk '{print $1}')
        elif command -v pidof >/dev/null 2>&1; then
            pids=$(pidof "$(basename "$DERPER_BIN")" 2>/dev/null)
        fi
    fi
    
    # 如果通过系统服务停止成功且没有残留进程
    if [ "$stop_success" = true ] && [ -z "$pids" ]; then
        case "$INIT_SYSTEM" in
            systemd)
                echo -e "${GREEN}✅ derper 已停止 (systemd)${RESET}"
                ;;
            openrc)
                echo -e "${GREEN}✅ derper 已停止 (OpenRC)${RESET}"
                ;;
        esac
        return 0
    fi
    
    # 如果还有进程在运行，使用强制停止
    if [ -n "$pids" ]; then
        echo -e "${YELLOW}检测到残留进程，使用强制进程停止...${RESET}"
        force_stop_derper
    else
        # 如果没有检测到进程但系统服务停止失败
        echo -e "${GREEN}✅ derper 已停止${RESET}"
    fi
}

#--------------------------------------------
# 强制停止 derper 进程
#--------------------------------------------
force_stop_derper() {
    # 查找 derper 进程（兼容不同系统）
    local pids=""
    if command -v ps >/dev/null 2>&1 && ps -eo pid,args >/dev/null 2>&1; then
        pids=$(ps -eo pid,args 2>/dev/null | grep -F "$DERPER_BIN" | grep -v grep | grep -v "ipderper.sh" | awk '{print $1}')
    elif command -v pidof >/dev/null 2>&1; then
        pids=$(pidof "$(basename "$DERPER_BIN")" 2>/dev/null)
    fi
    
    if [ -n "$pids" ]; then
        echo -e "${YELLOW}停止 derper 进程: $pids${RESET}"
        
        # 先尝试优雅停止
        for pid in $pids; do
            kill -TERM "$pid" 2>/dev/null && echo -e "${BLUE}已发送终止信号到 PID: $pid${RESET}"
        done
        
        # 等待进程结束
        local wait_time=0
        local max_wait=10
        while [ $wait_time -lt $max_wait ]; do
            local running_pids=""
            for pid in $pids; do
                if kill -0 "$pid" 2>/dev/null; then
                    running_pids="$running_pids $pid"
                fi
            done
            
            if [ -z "$running_pids" ]; then
                break
            fi
            
            sleep 1
            wait_time=$((wait_time + 1))
        done
        
        # 强制杀死剩余进程
        for pid in $pids; do
            if kill -0 "$pid" 2>/dev/null; then
                echo -e "${RED}强制杀死进程: $pid${RESET}"
                kill -KILL "$pid" 2>/dev/null
            fi
        done
    fi
    
    echo -e "${GREEN}✅ derper 已强制停止${RESET}"
}

#--------------------------------------------
# 配置生成
#--------------------------------------------
generate_config() {
    
    # --- 1. 备份现有配置 ---
    if [ -f "$CONFIG_FILE" ]; then
        cp "$CONFIG_FILE" "$CONFIG_FILE.bak"
        echo -e "${YELLOW}配置文件已备份为 $CONFIG_FILE.bak${RESET}"
    fi

    # --- 2. 获取公网 IP 作为 DERP_HOST 默认值 ---
    echo -e "正在检测公网 IP (默认 DERP_HOST)..."
    # 使用 curl -s 4.ipw.cn 获取公网 IP
    DEFAULT_HOST=$(curl -s 4.ipw.cn)
    
    # 检查 curl 是否成功获取 IP
    if [ $? -ne 0 ] || [ -z "$DEFAULT_HOST" ]; then
        echo -e "${RED}⚠️ IP 检测失败或网络不通。默认 DERP_HOST 将使用 127.0.0.1${RESET}"
        DEFAULT_HOST="127.0.0.1"
    else
        echo -e "${GREEN}✅ 检测到的公网 IP: $DEFAULT_HOST${RESET}"
    fi

    # --- 3. 获取 DERP_HOST 输入 (2秒默认值) ---
    echo -e "\n默认 DERP_HOST: ${YELLOW}$DEFAULT_HOST${RESET}"
    echo -n "输入主机名/IP (回车使用默认, 2秒后自动选择,按任意键打断): "
    
    # -t 2 设置超时2秒, -n 1 接收1个字符, -s 隐藏输入
    read -r -t 2 -n 1 USER_CHAR 
    
    if [ $? -eq 0 ]; then
        # 如果在 2 秒内按下了任意键，清空输入行并等待完整输入
        echo 
        read -r -p "继续输入主机名/IP: " USER_HOST
    else
        # 2 秒超时
        echo 
        USER_HOST=""
    fi
    
    DERP_HOST=${USER_HOST:-$DEFAULT_HOST}
    echo -e "${GREEN}⭐ 最终 DERP_HOST: $DERP_HOST${RESET}"


    # --- 4. 获取 DERP_ADDR 端口输入 ---
    RANDOM_PORT=$(od -An -N2 -i /dev/urandom | awk -v min=10000 -v max=65535 '{print ($1 % (max - min + 1)) + min}')
    echo
    echo -e "默认随机端口: ${YELLOW}$RANDOM_PORT${RESET}"
    read -r -p "输入端口(回车使用默认): " USER_PORT
    DERP_PORT=${USER_PORT:-$RANDOM_PORT}
    echo -e "${GREEN}⭐ 最终 DERP_PORT: $DERP_PORT${RESET}"

    # --- 5. 生成配置文件 ---
    cp "$CONFIG_TEMPLATE" "$CONFIG_FILE"
    
    # 1. 移除 JSON 注释
    sed -i 's|//.*$||' "$CONFIG_FILE"
    
    # 2. 使用 jq 更新 DERP_ADDR 和 DERP_HOST
    # 注意: jq 的 tostring 是必须的，因为 DERP_ADDR 在模板中是 ":47100" 这种格式。
    # 更好的方式是直接将 DERP_ADDR 设置为 "$port"
    jq --arg port "$DERP_PORT" \
       --arg host "$DERP_HOST" \
       '.DERP_ADDR = ($port|tonumber) | .DERP_HOST = $host' "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"

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
# pre loading sone variables from detect or load
detect_system 
load_derper_config
while true; do
    status_checker
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
        2) exit_derper
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
