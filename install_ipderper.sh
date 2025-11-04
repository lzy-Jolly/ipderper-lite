
#!/bin/sh
# this is install_ipderper.sh
set -e

DEST_DIR="/etc/ipderperd"
APP_DIR="$DEST_DIR/app"
LOG_DIR="$DEST_DIR/logs"
LINK="/usr/local/bin/ipderper"

GITHUB_REPO="lzy-Jolly/ipderper-lite"
GITHUB_RAW="https://raw.githubusercontent.com/${GITHUB_REPO}/main"
S3_URL="https://ipderperd.jooly.cloud/app.tar"
TEMP_TAR="/tmp/app.tar"

# 检查 root 权限
if [ "$(id -u)" -ne 0 ]; then
    echo "需要以 root 用户执行脚本，请添加sudo或切换到root用户后重试"
    exit 1
fi

# 系统类型检测
OS_TYPE=$(awk -F= '/^ID=/{print $2}' /etc/os-release | tr -d '"')
echo "项目支持系统：Alpine、Debian、Ubuntu"

case "$OS_TYPE" in
  alpine|debian|ubuntu)
    echo "检测到系统: $OS_TYPE"
    ;;
  *)
    echo "当前系统为 $OS_TYPE，可能无法正确安装，是否强制继续？(y/n) 默认n"
    read -r FORCE_CONTINUE
    FORCE_CONTINUE=$(echo "$FORCE_CONTINUE" | tr '[:upper:]' '[:lower:]')
    if [ "$FORCE_CONTINUE" = "y" ] || [ "$FORCE_CONTINUE" = "yes" ]; then
        echo "⚠️ ok现在强制继续安装"
    else
        exit 1
    fi
    ;;
esac

# 检查并安装依赖
DEPENDENCIES="curl openssl jq"
MISSING=""
for CMD in $DEPENDENCIES; do
    if ! command -v $CMD >/dev/null 2>&1; then
        MISSING="$MISSING $CMD"
    fi
done

if [ -n "$MISSING" ]; then
    echo "安装缺少的依赖:$MISSING"
    if [ "$OS_TYPE" = "alpine" ]; then
        apk add --no-cache $MISSING
    else
        apt-get update && apt-get install -y $MISSING
    fi
fi

# 创建安装目录和app目录
mkdir -p "$DEST_DIR"
mkdir -p "$APP_DIR"
mkdir -p "$LOG_DIR"
chmod 755 "$DEST_DIR"

# --- 👇 修改后的下载逻辑 START 👇 ---

# 尝试优先使用 GitHub 方式下载，设置 5 秒连接和接收超时
echo "尝试使用 GitHub 原始网址下载 (优先方式, 5秒超时)..."
GITHUB_SUCCESS=0
if curl -fsSL --connect-timeout 5 --max-time 5 "${GITHUB_RAW}/app/derper" -o "${DEST_DIR}/derper.test"; then
    echo "✅ GitHub 原始网址连接成功，将使用此方式下载所有文件。"
    GITHUB_SUCCESS=1
    # 删除测试文件
    rm -f "${DEST_DIR}/derper.test"
else
    echo "❌ GitHub 原始网址连接/下载失败或超时 (5秒)，切换到 S3 存储方式。"
fi

# 清理旧的 app 目录以避免冲突
rm -rf "$APP_DIR" 
mkdir -p "$APP_DIR" # 无论哪种方式，都需要确保 APP_DIR 存在

if [ "$GITHUB_SUCCESS" -eq 1 ]; then
    # **GitHub 方式下载所有文件**
FILES="derper ipderper.sh build_cert.sh config.jsonc"
for FILE in $FILES; do
    echo "下载 $FILE ..."
        # 设置一个更长的超时时间来完成下载
        if ! curl -fsSL --max-time 30 "${GITHUB_RAW}/app/${FILE}" -o "${APP_DIR}/${FILE}"; then
            echo "❌ 下载 $FILE 失败，中断安装。"
            exit 1
        fi
    done
    
else
    # **S3 存储方式下载和解压**
    echo "下载 S3 存储的 app.tar 压缩包..."
    if ! curl -fsSL "$S3_URL" -o "$TEMP_TAR"; then
        echo "❌ S3 压缩包下载失败，中断安装。"
        exit 1
    fi

    echo "解压 app.tar 到 $DEST_DIR (会生成 $APP_DIR 目录)..."
    if ! tar -xf "$TEMP_TAR" -C "$DEST_DIR"; then
        echo "❌ 解压 app.tar 失败，中断安装。"
        rm -f "$TEMP_TAR" || true
        exit 1
    fi

    echo "清理临时文件 $TEMP_TAR..."
    rm -f "$TEMP_TAR" || true
fi

# --- 👆 修改后的下载逻辑 END 👆 ---

# 统一赋权和设置所有权 (适用于两种下载方式)
echo "设置文件权限和所有权..."
# 遍历 $APP_DIR 中的所有文件和目录进行赋权
find "$APP_DIR" -type f -exec chmod +x {} \; || true # 赋予可执行权限
find "$APP_DIR" -exec chown root:root {} \;

# 建立全局软链接（指向app目录下的脚本）
ln -sf "${APP_DIR}/ipderper.sh" "$LINK"
chmod 755 "$LINK"

echo "✅ 已成功安装 ipderper 工具到 $APP_DIR"
echo "全局命令: ipderper 查看版本信息 ipderper -v"
echo ""
echo "如有报错如需卸载，请执行："
echo "  sudo rm -f /usr/local/bin/ipderper  # 删除软连接"
echo "  sudo rm -rf /etc/ipderperd          # 删除安装目录"
echo "  sudo rm -f /etc/systemd/system/selfipderperd.service # 删除 systemd 服务文件（如有）"
echo "  sudo rm -f /etc/logrotate.d/selfipderperd  # 删除日志轮转配置（如有）"
