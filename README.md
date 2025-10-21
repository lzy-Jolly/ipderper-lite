# ipderper-lite

[English](README_EN.md) | 简体中文

ipderper-lite — 轻量级一键脚本，可在 Ubuntu、Debian 和 Alpine Linux 系统上运行 ipderper for tailscale

## 简介

ipderper-lite 是一个轻量级的自动化部署脚本，用于在 Linux 系统上快速安装和配置 ipderper for Tailscale。该脚本支持多个主流 Linux 发行版，让您能够轻松地在服务器上设置 ipderper。

## 支持的系统

- Ubuntu
- Debian
- Alpine Linux

## 功能特性

- 🚀 一键安装，操作简单
- 🔧 自动检测系统类型
- 📦 轻量级设计
- ⚡ 快速部署
- 🔄 支持多个 Linux 发行版

## 安装方法

### 快速安装

```bash
# 下载并运行安装脚本
curl -sSL https://raw.githubusercontent.com/lzy-Jolly/ipderper-lite/main/install.sh | bash
```

或

```bash
# 使用 wget
wget -qO- https://raw.githubusercontent.com/lzy-Jolly/ipderper-lite/main/install.sh | bash
```

### 手动安装

1. 克隆仓库：
```bash
git clone https://github.com/lzy-Jolly/ipderper-lite.git
cd ipderper-lite
```

2. 运行安装脚本：
```bash
chmod +x install.sh
./install.sh
```

## 使用说明

安装完成后，ipderper 将自动配置并运行。您可以按照脚本提示完成后续配置。

## 卸载

如需卸载 ipderper，请运行：

```bash
# 卸载命令（具体根据实际脚本实现）
./uninstall.sh
```

## 故障排除

如果在安装过程中遇到问题：

1. 确保您有 root 或 sudo 权限
2. 检查系统是否为支持的 Linux 发行版
3. 确认网络连接正常
4. 查看安装日志以获取详细错误信息

## 贡献

欢迎提交 Issue 和 Pull Request！

## 许可证

本项目采用开源许可证，详见 LICENSE 文件。

## 相关链接

- [ipderper](https://github.com/lzy-Jolly/ipderper) - 主项目
- [Tailscale](https://tailscale.com/) - Tailscale 官网

## 联系方式

如有问题或建议，请通过 GitHub Issues 联系我们。
