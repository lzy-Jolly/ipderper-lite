# ipderper-lite

ipderper-lite — 轻量级一键脚本，可在 Ubuntu、Debian 和 Alpine Linux 系统上运行 ipderper for tailscale

## 简介 (Introduction)

ipderper-lite 是一个轻量级的一键安装脚本，用于在 Linux 系统上快速部署 ipderper（Tailscale 的自定义 DERP 服务器）。

ipderper-lite is a lightweight one-click installation script for quickly deploying ipderper (a custom DERP server for Tailscale) on Linux systems.

## 支持的系统 (Supported Systems)

- Ubuntu (18.04+)
- Debian (9+)
- Alpine Linux (3.12+)

## 功能特性 (Features)

- ✅ 自动检测 Linux 发行版
- ✅ 自动安装所需依赖
- ✅ 自动编译和部署 ipderper
- ✅ 自动创建系统服务（systemd/OpenRC）
- ✅ 支持服务开机自启
- ✅ 简单的服务管理命令

## 快速开始 (Quick Start)

### 一键安装 (One-Click Installation)

```bash
curl -fsSL https://raw.githubusercontent.com/lzy-Jolly/ipderper-lite/main/install.sh | sudo bash
```

或者 (Or):

```bash
wget -qO- https://raw.githubusercontent.com/lzy-Jolly/ipderper-lite/main/install.sh | sudo bash
```

### 手动安装 (Manual Installation)

```bash
# 下载脚本 (Download script)
git clone https://github.com/lzy-Jolly/ipderper-lite.git
cd ipderper-lite

# 执行安装 (Run installation)
sudo bash install.sh
```

## 使用说明 (Usage)

### Ubuntu/Debian 系统

```bash
# 启动服务 (Start service)
sudo systemctl start ipderper

# 停止服务 (Stop service)
sudo systemctl stop ipderper

# 重启服务 (Restart service)
sudo systemctl restart ipderper

# 查看状态 (Check status)
sudo systemctl status ipderper

# 查看日志 (View logs)
sudo journalctl -u ipderper -f
```

### Alpine Linux 系统

```bash
# 启动服务 (Start service)
sudo rc-service ipderper start

# 停止服务 (Stop service)
sudo rc-service ipderper stop

# 重启服务 (Restart service)
sudo rc-service ipderper restart

# 查看状态 (Check status)
sudo rc-service ipderper status
```

## 配置说明 (Configuration)

安装完成后，ipderper 将被安装到 `/opt/ipderper` 目录。

After installation, ipderper will be installed in the `/opt/ipderper` directory.

可以在该目录下找到配置文件并根据需要进行修改。

You can find the configuration files in that directory and modify them as needed.

## 卸载 (Uninstallation)

### Ubuntu/Debian

```bash
sudo systemctl stop ipderper
sudo systemctl disable ipderper
sudo rm /etc/systemd/system/ipderper.service
sudo systemctl daemon-reload
sudo rm -rf /opt/ipderper
```

### Alpine Linux

```bash
sudo rc-service ipderper stop
sudo rc-update del ipderper
sudo rm /etc/init.d/ipderper
sudo rm -rf /opt/ipderper
```

## 依赖项 (Dependencies)

脚本会自动安装以下依赖：

The script will automatically install the following dependencies:

- Git
- Wget
- Curl
- Go (Golang)

## 故障排除 (Troubleshooting)

### 端口占用 (Port Already in Use)

如果遇到端口占用问题，请检查是否有其他服务占用了 DERP 默认端口。

If you encounter a port conflict, check if other services are using the default DERP port.

### 编译失败 (Build Failure)

确保系统有足够的内存和磁盘空间，Go 编译需要一定的资源。

Ensure your system has sufficient memory and disk space, as Go compilation requires resources.

### 服务启动失败 (Service Start Failure)

查看日志以获取详细错误信息：

Check logs for detailed error information:

```bash
# Ubuntu/Debian
sudo journalctl -u ipderper -n 50

# Alpine Linux
sudo rc-service ipderper status
```

## 贡献 (Contributing)

欢迎提交 Issue 和 Pull Request！

Issues and Pull Requests are welcome!

## 许可证 (License)

MIT License

## 相关链接 (Related Links)

- [Tailscale](https://tailscale.com/)
- [DERP Protocol](https://tailscale.com/kb/1232/derp-servers/)
- [ipderper](https://github.com/lzy-Jolly/ipderper)
