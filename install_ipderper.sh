
#!/bin/sh
# this is install_ipderper.sh
set -e

DEST_DIR="/etc/ipderperd"
APP_DIR="$DEST_DIR/app"
LINK="/usr/local/bin/ipderper"

GITHUB_REPO="lzy-Jolly/ipderper-lite"
GITHUB_RAW="https://raw.githubusercontent.com/${GITHUB_REPO}/main"

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
chmod 755 "$DEST_DIR"
chmod 755 "$APP_DIR"

# 下载文件到app目录
FILES="derper ipderper.sh build_cert.sh config.jsonc"
for FILE in $FILES; do
    echo "下载 $FILE ..."
    if ! curl -fsSL "${GITHUB_RAW}/app/${FILE}" -o "${APP_DIR}/${FILE}"; then
        echo "❌ 下载 $FILE 失败"
        exit 1
    fi
    chmod +x "${APP_DIR}/${FILE}" || true
    chown root:root "${APP_DIR}/${FILE}"
done

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
