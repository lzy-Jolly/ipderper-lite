# this is install_ipderper.sh

#!/bin/sh
set -e

SRC="./ipderper.sh"
DEST_DIR="/etc/ipderperd"
DEST="${DEST_DIR}/ipderper.sh"
LINK="/usr/local/bin/ipderper"

GITHUB_REPO="lzy-Jolly/ipderper-lite"
GITHUB_RAW="https://raw.githubusercontent.com/${GITHUB_REPO}"

# 检查 root 权限
if [ "$(id -u)" -ne 0 ]; then
    echo "需要将 ipderper 添加进系统目录，请以 root 用户执行当前脚本"
    exit 1
fi

# 检查 VERSION 是否设置（环境变量）
if [ -n "$VERSION" ]; then
    echo "检测到指定版本：$VERSION"
    FILE_URL="https://github.com/${GITHUB_REPO}/releases/download/v${VERSION}/ipderper.sh"
else
    echo "未指定版本，默认安装最新 main 分支版本"
    FILE_URL="${GITHUB_RAW}/main/ipderper.sh"
fi

# 创建目录
mkdir -p "${DEST_DIR}"
chmod 755 "${DEST_DIR}"

# 检查本地版本
LOCAL_VERSION="0"
if [ -f "${DEST}" ]; then
    LOCAL_VERSION=$(grep '^VERSION=' "${DEST}" | cut -d'"' -f2)
fi

# 下载目标版本脚本
echo "从 ${FILE_URL} 下载 ipderper.sh ..."
curl -fsSL "${FILE_URL}" -o "${DEST}" || {
    echo "❌ 下载失败，请检查版本号或网络连接"
    exit 1
}

chmod 755 "${DEST}"
chown root:root "${DEST}"

# 建立全局符号链接
mkdir -p /usr/local/bin
ln -sf "${DEST}" "${LINK}"
chmod 755 "${LINK}"

NEW_VERSION=$(grep '^VERSION=' "${DEST}" | cut -d'"' -f2)
echo "✅ 已安装 ipderper version=${NEW_VERSION}"

echo ""
echo "如需卸载 ipderper，请执行："
echo "  sudo rm -f /usr/local/bin/ipderper"
echo "  sudo rm -rf /etc/ipderperd"

