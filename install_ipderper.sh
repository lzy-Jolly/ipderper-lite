# this is install_ipderper.sh

#!/bin/sh
set -e

# =========================
# ipderper 安装脚本
# 支持 VERSION=1.0.0 环境变量控制版本
# =========================

REPO_USER="lzy-Jolly"
REPO_NAME="ipderper-lite"

SRC="./ipderper.sh"
DEST_DIR="/etc/ipderperd"
DEST="${DEST_DIR}/ipderper.sh"
LINK="/usr/local/bin/ipderper"

# 判断是否 root
if [ "$(id -u)" -ne 0 ]; then
    echo "⚠️ 当前非 root 用户，正在尝试以普通用户安装..."
    SUDO_CMD=""
else
    SUDO_CMD=""
fi

# 检查 VERSION 变量
if [ -z "$VERSION" ]; then
    echo "未指定版本，将安装最新版本（main 分支）"
    GITHUB_REPO="https://raw.githubusercontent.com/${REPO_USER}/${REPO_NAME}/main/ipderper.sh"
else
    echo "🔖 指定安装版本: v${VERSION}"
    GITHUB_REPO="https://github.com/${REPO_USER}/${REPO_NAME}/releases/download/v${VERSION}/ipderper.sh"
fi

# 创建安装目录
mkdir -p "${DEST_DIR}"
chmod 755 "${DEST_DIR}"

# 检查本地版本
LOCAL_VERSION="0"
if [ -f "${DEST}" ]; then
    LOCAL_VERSION=$(grep '^VERSION=' "${DEST}" | cut -d'"' -f2)
fi

# 获取远程版本
REMOTE_VERSION=$(curl -fsSL "${GITHUB_REPO}" | grep '^VERSION=' | cut -d'"' -f2 || echo "")

if [ -n "$REMOTE_VERSION" ] && [ "$REMOTE_VERSION" != "$LOCAL_VERSION" ]; then
    echo "🆕 发现新版本 ipderper ${REMOTE_VERSION}，正在下载..."
    curl -fsSL "${GITHUB_REPO}" -o "${DEST}"
else
    echo "✅ 当前版本 ipderper ${LOCAL_VERSION} 已是最新"
    [ ! -f "${DEST}" ] && cp -p "${SRC}" "${DEST}"
fi

chmod 755 "${DEST}"
chown root:root "${DEST}" 2>/dev/null || true

# 创建符号链接
mkdir -p /usr/local/bin
ln -sf "${DEST}" "${LINK}"
chmod 755 "${LINK}"

echo
echo "✨ 安装完成！"
echo "当前版本：$(grep '^VERSION=' ${DEST} | cut -d'\"' -f2)"
echo
echo "运行命令查看版本：ipderper -v"
echo "如需卸载，请执行："
echo "  rm -f /usr/local/bin/ipderper"
echo "  rm -rf /etc/ipderperd"
echo

