#!/bin/bash

# Surface Kernel Uninstaller for Pop!_OS
# Reverts to the default Pop!_OS kernel

set -e  # Exit on any error

echo "=========================================="
echo "Surface Kernel Uninstaller for Pop!_OS"
echo "=========================================="
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root (use sudo)"
    exit 1
fi

ESP_PATH="/boot/efi"
BOOT_ENTRY="${ESP_PATH}/loader/entries/Pop_OS-surface.conf"

echo "This will:"
echo "  1. Remove the Surface kernel boot entry"
echo "  2. Set Pop!_OS default kernel as default"
echo "  3. Optionally remove Surface kernel packages"
echo ""
read -p "Do you want to continue? (y/N): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 0
fi

# Remove boot entry
if [ -f "$BOOT_ENTRY" ]; then
    echo ""
    echo "[1/3] Removing Surface kernel boot entry..."
    rm "$BOOT_ENTRY"
    echo "✓ Boot entry removed"
else
    echo ""
    echo "[1/3] No Surface kernel boot entry found"
fi

# Set default kernel back to Pop_OS-current
echo ""
echo "[2/4] Setting Pop!_OS default kernel as boot default..."
bootctl set-default Pop_OS-current.conf
echo "✓ Default boot entry set to Pop_OS-current.conf"

# Remove automatic update configuration
echo ""
echo "[3/4] Removing automatic update configuration..."

APT_HOOK="/etc/apt/apt.conf.d/90surface-kernel"
UPDATE_SCRIPT="/usr/local/bin/update-surface-kernel.sh"

if [ -f "$APT_HOOK" ]; then
    rm "$APT_HOOK"
    echo "✓ APT hook removed"
else
    echo "✓ No APT hook found"
fi

if [ -f "$UPDATE_SCRIPT" ]; then
    rm "$UPDATE_SCRIPT"
    echo "✓ Update script removed"
else
    echo "✓ No update script found"
fi

# Ask about removing packages
echo ""
echo "[4/4] Remove Surface kernel packages?"
echo "This will uninstall the Surface kernel but keep the repository configured."
read -p "Remove packages? (y/N): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Removing Surface kernel packages..."
    apt remove --purge -y linux-image-surface linux-headers-surface
    echo "✓ Packages removed"
else
    echo "✓ Packages kept (you can remove them later with: sudo apt remove linux-image-surface linux-headers-surface)"
fi

echo ""
echo "=========================================="
echo "Surface Kernel Uninstallation Complete!"
echo "=========================================="
echo ""
echo "The system will now boot with the default Pop!_OS kernel."
echo ""
echo "Current boot entries:"
bootctl list | grep -E "title:|id:" | head -10
echo ""

# Check if Howdy is installed and offer to remove it
HOWDY_UNINSTALL="$(dirname "$(readlink -f "$0")")/uninstall-howdy.sh"

if dpkg -l | grep -q "^ii.*howdy" || [ -f /etc/pam.d/gdm-password ] && grep -q "howdy" /etc/pam.d/gdm-password 2>/dev/null; then
    echo ""
    echo "=========================================="
    echo "Howdy Facial Recognition Detected"
    echo "=========================================="
    echo ""
    read -p "Would you also like to remove Howdy facial recognition? (y/N): " REMOVE_HOWDY
    if [[ "$REMOVE_HOWDY" =~ ^[Yy]$ ]]; then
        if [ -f "$HOWDY_UNINSTALL" ]; then
            bash "$HOWDY_UNINSTALL"
        else
            echo "Howdy uninstaller not found. Removing manually..."
            # Disable in PAM
            sed -i '/pam_python.so.*howdy/d' /etc/pam.d/gdm-password 2>/dev/null || true
            # Remove safety service
            systemctl disable howdy-check.service 2>/dev/null || true
            rm -f /etc/systemd/system/howdy-check.service
            rm -f /usr/local/bin/howdy-precheck.sh
            rm -f /usr/local/bin/howdy-diagnose.py
            systemctl daemon-reload
            echo "✓ Howdy disabled"
        fi
    fi
fi

echo ""
echo "Please reboot to switch back to the Pop!_OS kernel."
echo "To reboot now, run: sudo reboot"