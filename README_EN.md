# ipderper-lite

English | [简体中文](README.md)

ipderper-lite — A lightweight one-click script to run ipderper for Tailscale on Ubuntu, Debian, and Alpine Linux systems

## Introduction

ipderper-lite is a lightweight automated deployment script for quickly installing and configuring ipderper for Tailscale on Linux systems. This script supports multiple mainstream Linux distributions, allowing you to easily set up ipderper on your server.

## Supported Systems

- Ubuntu
- Debian
- Alpine Linux

## Features

- 🚀 One-click installation, simple operation
- 🔧 Automatic system type detection
- 📦 Lightweight design
- ⚡ Fast deployment
- 🔄 Support for multiple Linux distributions

## Installation

### Quick Install

```bash
# Download and run the installation script
curl -sSL https://raw.githubusercontent.com/lzy-Jolly/ipderper-lite/main/install.sh | bash
```

Or

```bash
# Using wget
wget -qO- https://raw.githubusercontent.com/lzy-Jolly/ipderper-lite/main/install.sh | bash
```

### Manual Installation

1. Clone the repository:
```bash
git clone https://github.com/lzy-Jolly/ipderper-lite.git
cd ipderper-lite
```

2. Run the installation script:
```bash
chmod +x install.sh
./install.sh
```

## Usage

After installation is complete, ipderper will be automatically configured and running. You can follow the script prompts to complete the subsequent configuration.

## Uninstallation

To uninstall ipderper, run:

```bash
# Uninstall command (depends on actual script implementation)
./uninstall.sh
```

## Troubleshooting

If you encounter problems during installation:

1. Ensure you have root or sudo privileges
2. Verify that your system is a supported Linux distribution
3. Confirm that your network connection is working
4. Check the installation logs for detailed error information

## Contributing

Issues and Pull Requests are welcome!

## License

This project is licensed under an open source license. See the LICENSE file for details.

## Related Links

- [ipderper](https://github.com/lzy-Jolly/ipderper) - Main project
- [Tailscale](https://tailscale.com/) - Tailscale official website

## Contact

If you have any questions or suggestions, please contact us through GitHub Issues.
