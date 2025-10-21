# this is install_ipderper.sh

#!/bin/sh
set -e

SRC="./ipderper.sh"
DEST_DIR="/etc/ipderperd"
DEST="${DEST_DIR}/ipderper.sh"
LINK="/usr/local/bin/ipderper"

GITHUB_REPO="https://raw.githubusercontent.com/lzy-Jolly/ipderper-lite/main/ipderper.sh"

# 检查 root 权限
if [ "$(id -u)" -ne 0 ]; then
    echo "需要将 ipderper 添加进系统目录，请以 root 用户执行当前脚本"
    exit 1
fi

# 创建目录
mkdir -p "${DEST_DIR}"
chmod 755 "${DEST_DIR}"

# 检查本地版本
LOCAL_VERSION="0"
if [ -f "${DEST}" ]; then
    LOCAL_VERSION=$(grep '^VERSION=' "${DEST}" | cut -d'"' -f2)
fi

# 获取远程版本
REMOTE_VERSION=$(curl -fsSL "${GITHUB_REPO}" | grep '^VERSION=' | cut -d'"' -f2 || echo "")

if [ "$REMOTE_VERSION" != "" ] && [ "$REMOTE_VERSION" != "$LOCAL_VERSION" ]; then
    echo "发现新版本 ipderper ${REMOTE_VERSION}，正在更新..."
    curl -fsSL "${GITHUB_REPO}" -o "${DEST}"
else
    echo "当前版本 ipderper ${LOCAL_VERSION}已经与远端同步"
    # 如果没有本地文件，则复制当前目录下的源码
    [ ! -f "${DEST}" ] && cp -p "${SRC}" "${DEST}"
fi

chmod 755 "${DEST}"
chown root:root "${DEST}"

# 建立全局符号链接
mkdir -p /usr/local/bin
ln -sf "${DEST}" "${LINK}"
chmod 755 "${LINK}"

echo "确认本地版本：ipderper -v"
echo "如需卸载 ipderper，请执行："
echo "  sudo rm -f /usr/local/bin/ipderper"
echo "  sudo rm -rf /etc/ipderperd"
