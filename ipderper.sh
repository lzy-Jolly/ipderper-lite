# this is ipderper.sh
#!/bin/sh
VERSION="1.0"

# 支持大小写的版本查询
if [ $# -ge 1 ]; then
    arg=$(echo "$1" | tr '[:upper:]' '[:lower:]')
    if [ "$arg" = "-v" ] || [ "$arg" = "--version" ]; then
        echo "ipderper 当前版本version=$VERSION"
        exit 0
    fi
fi

# 临时测试用的 ipderper.sh —— 仅用于验证安装流程
echo "这是一个临时测试用的 ipderper.sh —— 仅用于验证安装流程"
echo "已经成功安装在系统自启目录"
