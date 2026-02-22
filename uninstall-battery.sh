#!/bin/bash

# Battery Optimization Uninstaller for Surface Devices
# Part of the Pop!_OS Surface Kernel setup

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }

echo ""
echo -e "${YELLOW}=========================================="
echo "Battery Optimization Uninstaller"
echo -e "==========================================${NC}"
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    error "Please run as root (use sudo)"
    exit 1
fi

echo "This will:"
echo "  1. Remove the Surface power tuning service"
echo "  2. Remove the powertop auto-tune service"
echo "  3. Remove the auto-cpufreq configuration"
echo "  4. Optionally remove auto-cpufreq and powertop packages"
echo ""
read -p "Do you want to continue? (y/N): " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 0
fi

# Step 1: Remove Surface power tuning service
echo ""
echo "[1/4] Removing Surface power tuning service..."

if systemctl is-enabled surface-power-tune.service >/dev/null 2>&1; then
    systemctl disable surface-power-tune.service
    success "Surface power tuning service disabled"
else
    success "Surface power tuning service was not enabled"
fi

if [[ -f /etc/systemd/system/surface-power-tune.service ]]; then
    rm /etc/systemd/system/surface-power-tune.service
    systemctl daemon-reload
    success "Service file removed"
fi

if [[ -f /usr/local/bin/surface-power-tune.sh ]]; then
    rm /usr/local/bin/surface-power-tune.sh
    success "Power tuning script removed"
fi

# Step 2: Remove powertop auto-tune service
echo ""
echo "[2/4] Removing powertop auto-tune service..."

if systemctl is-enabled powertop-autotune.service >/dev/null 2>&1; then
    systemctl disable powertop-autotune.service
    success "powertop auto-tune service disabled"
else
    success "powertop auto-tune service was not enabled"
fi

if [[ -f /etc/systemd/system/powertop-autotune.service ]]; then
    rm /etc/systemd/system/powertop-autotune.service
    systemctl daemon-reload
    success "Service file removed"
fi

# Step 3: Remove auto-cpufreq configuration and optionally the package
echo ""
echo "[3/4] Remove auto-cpufreq?"
echo ""
echo "If you keep auto-cpufreq installed, it will continue managing"
echo "CPU frequency with default settings."
echo ""
read -p "Remove auto-cpufreq package completely? (y/N): " REMOVE_AUTOCPUFREQ

if [[ "$REMOVE_AUTOCPUFREQ" =~ ^[Yy]$ ]]; then
    log "Stopping and removing auto-cpufreq..."
    # Handle both package and source installations
    if dpkg -l | grep -q "^ii.*auto-cpufreq"; then
        systemctl stop auto-cpufreq 2>/dev/null || true
        systemctl disable auto-cpufreq 2>/dev/null || true
        apt remove --purge -y auto-cpufreq || warn "Could not remove auto-cpufreq package"
    elif command -v auto-cpufreq >/dev/null 2>&1; then
        auto-cpufreq --remove 2>/dev/null || true
    fi
    success "auto-cpufreq removed"
else
    success "auto-cpufreq package kept"
    echo "  You can remove it later with: sudo auto-cpufreq --remove"
fi

# Remove config file either way
if [[ -f /etc/auto-cpufreq.conf ]]; then
    rm /etc/auto-cpufreq.conf
    success "auto-cpufreq config removed"
fi

# Step 4: Optionally remove powertop package
echo ""
echo "[4/4] Remove powertop package?"
echo ""
echo "powertop is a useful diagnostic tool even without the auto-tune service."
echo ""
read -p "Remove powertop package? (y/N): " REMOVE_POWERTOP

if [[ "$REMOVE_POWERTOP" =~ ^[Yy]$ ]]; then
    apt remove --purge -y powertop || warn "Could not remove powertop package"
    success "powertop removed"
else
    success "powertop package kept"
    echo "  You can still use it manually: sudo powertop"
fi

# Summary
echo ""
echo -e "${GREEN}=========================================="
echo "Battery Optimization Uninstalled!"
echo -e "==========================================${NC}"
echo ""
echo "Changes made:"
echo "  - Surface power tuning service removed"
echo "  - powertop auto-tune service removed"
echo "  - auto-cpufreq config removed"
if [[ "$REMOVE_AUTOCPUFREQ" =~ ^[Yy]$ ]]; then
    echo "  - auto-cpufreq package removed"
fi
if [[ "$REMOVE_POWERTOP" =~ ^[Yy]$ ]]; then
    echo "  - powertop package removed"
fi
echo ""
echo "Your system will use default power management settings."
echo "A reboot is recommended to fully revert changes."
echo ""
