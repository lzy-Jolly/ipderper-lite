# Quick Start Guide | 快速入门指南

## Installation | 安装

### One-line install | 一键安装
```bash
curl -fsSL https://raw.githubusercontent.com/lzy-Jolly/ipderper-lite/main/install.sh | sudo bash
```

## Service Management | 服务管理

### Ubuntu/Debian
```bash
sudo systemctl start ipderper    # Start
sudo systemctl stop ipderper     # Stop
sudo systemctl restart ipderper  # Restart
sudo systemctl status ipderper   # Status
```

### Alpine Linux
```bash
sudo rc-service ipderper start    # Start
sudo rc-service ipderper stop     # Stop
sudo rc-service ipderper restart  # Restart
sudo rc-service ipderper status   # Status
```

## Common Tasks | 常见任务

### Check logs | 查看日志
```bash
# Ubuntu/Debian
sudo journalctl -u ipderper -f

# Alpine (check syslog)
tail -f /var/log/messages | grep ipderper
```

### Verify installation | 验证安装
```bash
ls -la /opt/ipderper/
```

### Uninstall | 卸载
```bash
# Ubuntu/Debian
sudo systemctl stop ipderper
sudo systemctl disable ipderper
sudo rm /etc/systemd/system/ipderper.service
sudo systemctl daemon-reload
sudo rm -rf /opt/ipderper

# Alpine
sudo rc-service ipderper stop
sudo rc-update del ipderper
sudo rm /etc/init.d/ipderper
sudo rm -rf /opt/ipderper
```

## Troubleshooting | 故障排除

### Port conflicts | 端口冲突
```bash
# Check what's using the port
sudo netstat -tulpn | grep :3478
sudo lsof -i :3478
```

### Service won't start | 服务无法启动
```bash
# Check detailed logs
sudo journalctl -u ipderper -n 100 --no-pager
```

### Build errors | 编译错误
```bash
# Verify Go installation
go version

# Check disk space
df -h
```

## Need Help? | 需要帮助？

- [Full Documentation](README.md)
- [Report Issues](https://github.com/lzy-Jolly/ipderper-lite/issues)
- [ipderper Repository](https://github.com/lzy-Jolly/ipderper)
