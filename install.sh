#!/bin/bash

# ipderper-lite - Lightweight one-click script to run ipderper for Tailscale
# Supports: Ubuntu, Debian, and Alpine Linux

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
IPDERPER_REPO="https://github.com/lzy-Jolly/ipderper.git"
IPDERPER_DIR="/opt/ipderper"
SERVICE_NAME="ipderper"

# Print functions
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "Please run this script as root or with sudo"
        exit 1
    fi
}

# Detect Linux distribution
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        VERSION=$VERSION_ID
    elif [ -f /etc/alpine-release ]; then
        OS="alpine"
        VERSION=$(cat /etc/alpine-release)
    else
        print_error "Unable to detect Linux distribution"
        exit 1
    fi
    
    print_info "Detected OS: $OS $VERSION"
}

# Install dependencies for Ubuntu/Debian
install_deps_debian() {
    print_info "Installing dependencies for Debian/Ubuntu..."
    apt-get update
    apt-get install -y git wget curl golang-go
}

# Install dependencies for Alpine
install_deps_alpine() {
    print_info "Installing dependencies for Alpine Linux..."
    apk update
    apk add --no-cache git wget curl go
}

# Install dependencies based on OS
install_dependencies() {
    case $OS in
        ubuntu|debian)
            install_deps_debian
            ;;
        alpine)
            install_deps_alpine
            ;;
        *)
            print_error "Unsupported OS: $OS"
            exit 1
            ;;
    esac
}

# Clone or update ipderper repository
setup_ipderper() {
    print_info "Setting up ipderper..."
    
    if [ -d "$IPDERPER_DIR" ]; then
        print_warning "ipderper directory already exists. Updating..."
        cd "$IPDERPER_DIR"
        git pull
    else
        print_info "Cloning ipderper repository..."
        git clone "$IPDERPER_REPO" "$IPDERPER_DIR"
        cd "$IPDERPER_DIR"
    fi
}

# Build ipderper
build_ipderper() {
    print_info "Building ipderper..."
    cd "$IPDERPER_DIR"
    
    # Set Go environment
    export GOPATH=/root/go
    export PATH=$PATH:/usr/local/go/bin:$GOPATH/bin
    
    # Build the project
    go build -o ipderper
    
    if [ -f "ipderper" ]; then
        print_info "ipderper built successfully"
        chmod +x ipderper
    else
        print_error "Failed to build ipderper"
        exit 1
    fi
}

# Create systemd service for Ubuntu/Debian
create_systemd_service() {
    print_info "Creating systemd service..."
    
    cat > /etc/systemd/system/${SERVICE_NAME}.service <<EOF
[Unit]
Description=ipderper - Custom DERP server for Tailscale
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=${IPDERPER_DIR}
ExecStart=${IPDERPER_DIR}/ipderper
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable ${SERVICE_NAME}
    print_info "Systemd service created and enabled"
}

# Create OpenRC service for Alpine
create_openrc_service() {
    print_info "Creating OpenRC service..."
    
    cat > /etc/init.d/${SERVICE_NAME} <<EOF
#!/sbin/openrc-run

name="ipderper"
description="ipderper - Custom DERP server for Tailscale"
command="${IPDERPER_DIR}/ipderper"
command_background=true
pidfile="/run/\${RC_SVCNAME}.pid"

depend() {
    need net
    after firewall
}
EOF

    chmod +x /etc/init.d/${SERVICE_NAME}
    rc-update add ${SERVICE_NAME} default
    print_info "OpenRC service created and enabled"
}

# Create service based on OS
create_service() {
    case $OS in
        ubuntu|debian)
            create_systemd_service
            ;;
        alpine)
            create_openrc_service
            ;;
        *)
            print_error "Unsupported OS for service creation: $OS"
            exit 1
            ;;
    esac
}

# Start the service
start_service() {
    print_info "Starting ipderper service..."
    
    case $OS in
        ubuntu|debian)
            systemctl start ${SERVICE_NAME}
            systemctl status ${SERVICE_NAME} --no-pager
            ;;
        alpine)
            rc-service ${SERVICE_NAME} start
            rc-service ${SERVICE_NAME} status
            ;;
    esac
}

# Print completion message
print_completion() {
    echo ""
    echo "================================================"
    print_info "ipderper installation completed successfully!"
    echo "================================================"
    echo ""
    echo "Service management commands:"
    
    case $OS in
        ubuntu|debian)
            echo "  Start:   sudo systemctl start ${SERVICE_NAME}"
            echo "  Stop:    sudo systemctl stop ${SERVICE_NAME}"
            echo "  Restart: sudo systemctl restart ${SERVICE_NAME}"
            echo "  Status:  sudo systemctl status ${SERVICE_NAME}"
            echo "  Logs:    sudo journalctl -u ${SERVICE_NAME} -f"
            ;;
        alpine)
            echo "  Start:   sudo rc-service ${SERVICE_NAME} start"
            echo "  Stop:    sudo rc-service ${SERVICE_NAME} stop"
            echo "  Restart: sudo rc-service ${SERVICE_NAME} restart"
            echo "  Status:  sudo rc-service ${SERVICE_NAME} status"
            ;;
    esac
    
    echo ""
    echo "Configuration directory: ${IPDERPER_DIR}"
    echo ""
}

# Main installation flow
main() {
    print_info "Starting ipderper-lite installation..."
    echo ""
    
    check_root
    detect_os
    install_dependencies
    setup_ipderper
    build_ipderper
    create_service
    start_service
    print_completion
}

# Run main function
main
