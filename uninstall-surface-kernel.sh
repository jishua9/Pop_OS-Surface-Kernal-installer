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
echo "[2/3] Setting Pop!_OS default kernel as boot default..."
bootctl set-default Pop_OS-current.conf
echo "✓ Default boot entry set to Pop_OS-current.conf"

# Ask about removing packages
echo ""
echo "[3/3] Remove Surface kernel packages?"
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
echo "Uninstallation Complete!"
echo "=========================================="
echo ""
echo "The system will now boot with the default Pop!_OS kernel."
echo ""
echo "Current boot entries:"
bootctl list | grep -E "title:|id:" | head -10
echo ""
echo "Please reboot to switch back to the Pop!_OS kernel."
echo "To reboot now, run: sudo reboot"
