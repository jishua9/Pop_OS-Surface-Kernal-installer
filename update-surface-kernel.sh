#!/bin/bash

# Surface Kernel Update Script for Pop!_OS
# Run this after updating the linux-image-surface package

set -e  # Exit on any error

echo "=========================================="
echo "Surface Kernel Updater for Pop!_OS"
echo "=========================================="
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root (use sudo)"
    exit 1
fi

# Detect system information
echo "Detecting system configuration..."
ESP_PATH="/boot/efi"
ESP_DIR=$(ls -d ${ESP_PATH}/EFI/Pop_OS-* 2>/dev/null | head -1)

if [ -z "$ESP_DIR" ]; then
    echo "ERROR: Could not find Pop!_OS ESP directory"
    exit 1
fi

echo "ESP Directory: $ESP_DIR"
echo ""

# Detect current running kernel
CURRENT_KERNEL=$(uname -r)
echo "Currently running: $CURRENT_KERNEL"

# Detect latest installed Surface kernel
SURFACE_KERNEL=$(ls /boot/vmlinuz-*-surface* 2>/dev/null | sort -V | tail -1)
SURFACE_INITRD=$(ls /boot/initrd.img-*-surface* 2>/dev/null | sort -V | tail -1)

if [ -z "$SURFACE_KERNEL" ] || [ -z "$SURFACE_INITRD" ]; then
    echo "ERROR: Surface kernel not found in /boot/"
    exit 1
fi

KERNEL_VERSION=$(basename "$SURFACE_KERNEL" | sed 's/vmlinuz-//')
echo "Latest Surface kernel: $KERNEL_VERSION"
echo ""

# Check if update is needed
if [ "$CURRENT_KERNEL" == "$KERNEL_VERSION" ]; then
    echo "You are already running the latest Surface kernel."
    echo "No update needed."
    exit 0
fi

# Backup current kernel files
echo "Backing up current Surface kernel files..."
if [ -f "${ESP_DIR}/vmlinuz-surface.efi" ]; then
    cp "${ESP_DIR}/vmlinuz-surface.efi" "${ESP_DIR}/vmlinuz-surface.efi.backup"
fi
if [ -f "${ESP_DIR}/initrd-surface.img" ]; then
    cp "${ESP_DIR}/initrd-surface.img" "${ESP_DIR}/initrd-surface.img.backup"
fi
echo "✓ Backup complete"
echo ""

# Copy new kernel files
echo "Updating kernel files in ESP partition..."
cp "$SURFACE_KERNEL" "${ESP_DIR}/vmlinuz-surface.efi"
cp "$SURFACE_INITRD" "${ESP_DIR}/initrd-surface.img"
echo "✓ Kernel files updated"
echo ""

echo "=========================================="
echo "Update Complete!"
echo "=========================================="
echo ""
echo "Updated to: $KERNEL_VERSION"
echo "Currently running: $CURRENT_KERNEL"
echo ""
echo "Please reboot to use the new kernel."
echo "To reboot now, run: sudo reboot"
