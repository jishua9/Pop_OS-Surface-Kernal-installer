#!/bin/bash

# Battery Optimization Installation Script for Surface Devices
# Part of the Pop!_OS Surface Kernel setup
# Can be run standalone or called from install-surface-kernel.sh

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

# Get script directory for accessing config files
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
BATTERY_CONFIG_DIR="${SCRIPT_DIR}/batteryConfig"

echo ""
echo -e "${YELLOW}=========================================="
echo "Battery Optimization Installer"
echo "for Surface Devices on Pop!_OS"
echo -e "==========================================${NC}"
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    error "Please run as root (use sudo)"
    exit 1
fi

# Check if batteryConfig directory exists
if [[ ! -d "$BATTERY_CONFIG_DIR" ]]; then
    error "batteryConfig directory not found at: $BATTERY_CONFIG_DIR"
    error "Please ensure the script is in the correct location"
    exit 1
fi

# Step 1: Install powertop
echo "[1/6] Installing powertop..."

if dpkg -l | grep -q "^ii.*powertop"; then
    success "powertop already installed"
else
    apt update
    apt install -y powertop
    success "powertop installed"
fi

# Step 2: Install auto-cpufreq
echo ""
echo "[2/6] Installing auto-cpufreq..."

if dpkg -l | grep -q "^ii.*auto-cpufreq"; then
    success "auto-cpufreq already installed"
else
    # Try PPA first
    PPA_SUCCESS=false
    if ! grep -q "auto-cpufreq" /etc/apt/sources.list.d/*.list 2>/dev/null; then
        log "Adding auto-cpufreq PPA..."
        if add-apt-repository -y ppa:auto-cpufreq/ppa 2>/dev/null; then
            apt update
            PPA_SUCCESS=true
        else
            warn "PPA not available for this release"
        fi
    else
        PPA_SUCCESS=true
    fi

    if $PPA_SUCCESS; then
        apt install -y auto-cpufreq
        success "auto-cpufreq installed via PPA"
    else
        # Fallback: install from git
        log "Installing auto-cpufreq from source..."
        apt install -y git python3-pip
        TEMP_DIR=$(mktemp -d)
        git clone https://github.com/AdnanHodzic/auto-cpufreq.git "$TEMP_DIR/auto-cpufreq"
        cd "$TEMP_DIR/auto-cpufreq"
        ./auto-cpufreq-installer --install
        cd "$SCRIPT_DIR"
        rm -rf "$TEMP_DIR"
        success "auto-cpufreq installed from source"
    fi

    # Enable and start the daemon
    # Source install uses --install to set up its own service
    if systemctl list-unit-files | grep -q auto-cpufreq; then
        systemctl enable auto-cpufreq
        systemctl start auto-cpufreq
    elif command -v auto-cpufreq >/dev/null 2>&1; then
        auto-cpufreq --install
    fi
    success "auto-cpufreq service enabled and started"
fi

# Step 3: Configure auto-cpufreq for Surface
echo ""
echo "[3/6] Configuring auto-cpufreq for Surface..."

if [[ -f /etc/auto-cpufreq.conf ]]; then
    cp /etc/auto-cpufreq.conf "/etc/auto-cpufreq.conf.backup.$(date +%Y%m%d_%H%M%S)"
    log "Backed up existing config"
fi

cp "${BATTERY_CONFIG_DIR}/auto-cpufreq.conf" /etc/auto-cpufreq.conf
chmod 644 /etc/auto-cpufreq.conf

# Restart to pick up new config
systemctl restart auto-cpufreq

success "auto-cpufreq configured for Surface"
echo "  Charger: governor=performance, turbo=auto"
echo "  Battery: governor=powersave, turbo=off"

# Step 4: Install powertop auto-tune service
echo ""
echo "[4/6] Installing powertop auto-tune service..."

cp "${BATTERY_CONFIG_DIR}/powertop-autotune.service" /etc/systemd/system/
chmod 644 /etc/systemd/system/powertop-autotune.service
systemctl daemon-reload
systemctl enable powertop-autotune.service

success "powertop auto-tune service enabled"
echo "  Runs powertop --auto-tune at every boot"

# Step 5: Install Surface power tuning service
echo ""
echo "[5/6] Installing Surface power tuning service..."

cp "${BATTERY_CONFIG_DIR}/surface-power-tune.sh" /usr/local/bin/
chmod +x /usr/local/bin/surface-power-tune.sh

cp "${BATTERY_CONFIG_DIR}/surface-power-tune.service" /etc/systemd/system/
chmod 644 /etc/systemd/system/surface-power-tune.service
systemctl daemon-reload
systemctl enable surface-power-tune.service

success "Surface power tuning service enabled"
echo "  Optimizes USB wake, NVMe, PCI, SATA, and audio power settings"

# Step 6: Verify configuration
echo ""
echo "[6/6] Verifying configuration..."

# Check auto-cpufreq service
if systemctl is-active --quiet auto-cpufreq; then
    success "auto-cpufreq service is running"
else
    warn "auto-cpufreq service is not running (will start on reboot)"
fi

# Show current governor
GOVERNOR=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo "unknown")
log "Current CPU governor: $GOVERNOR"

# Show battery info if available
for bat in /sys/class/power_supply/BAT*; do
    if [[ -d "$bat" ]]; then
        BAT_NAME=$(basename "$bat")
        BAT_STATUS=$(cat "$bat/status" 2>/dev/null || echo "unknown")
        BAT_CAPACITY=$(cat "$bat/capacity" 2>/dev/null || echo "unknown")
        log "$BAT_NAME: $BAT_STATUS ($BAT_CAPACITY%)"
    fi
done

# Check powertop service
if systemctl is-enabled --quiet powertop-autotune.service 2>/dev/null; then
    success "powertop auto-tune service is enabled"
fi

# Check surface power tune service
if systemctl is-enabled --quiet surface-power-tune.service 2>/dev/null; then
    success "Surface power tuning service is enabled"
fi

# Final summary
echo ""
echo -e "${GREEN}=========================================="
echo "Battery Optimization Complete!"
echo -e "==========================================${NC}"
echo ""
echo "Installed components:"
echo "  - auto-cpufreq: Dynamic CPU frequency management"
echo "  - powertop auto-tune: Device power optimization at boot"
echo "  - Surface power tuning: Hardware-specific power settings"
echo ""
echo "How it works:"
echo "  1. auto-cpufreq dynamically adjusts CPU governor and turbo"
echo "  2. powertop applies device power optimizations at each boot"
echo "  3. Surface-specific tuning disables unnecessary wake devices"
echo ""
echo "Useful commands:"
echo "  sudo auto-cpufreq --stats    - View current power stats"
echo "  sudo powertop                - Interactive power analysis"
echo "  systemctl status auto-cpufreq - Check auto-cpufreq service"
echo ""
echo -e "${GREEN}Full effect requires a reboot.${NC}"
echo "To reboot now, run: sudo reboot"
echo ""
