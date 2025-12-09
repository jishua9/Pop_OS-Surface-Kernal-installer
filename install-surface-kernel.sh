#!/bin/bash

# Surface Kernel Installation Script for Pop!_OS
# Automates download, installation, and configuration of the Linux Surface kernel

set -e  # Exit on any error

echo "=========================================="
echo "Surface Kernel Installer for Pop!_OS"
echo "=========================================="
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root (use sudo)"
    exit 1
fi

# Detect system information
echo "Detecting system configuration..."
ROOT_UUID=$(findmnt -n -o UUID /)
ESP_PATH="/boot/efi"
ESP_DIR=$(ls -d ${ESP_PATH}/EFI/Pop_OS-* 2>/dev/null | head -1)

if [ -z "$ESP_DIR" ]; then
    echo "ERROR: Could not find Pop!_OS ESP directory"
    exit 1
fi

echo "Root UUID: $ROOT_UUID"
echo "ESP Path: $ESP_PATH"
echo "ESP Directory: $ESP_DIR"
echo ""

# Step 1: Add Surface Linux repository
echo "[1/8] Adding Surface Linux repository..."
if [ ! -f /etc/apt/trusted.gpg.d/linux-surface.gpg ]; then
    wget -qO - https://raw.githubusercontent.com/linux-surface/linux-surface/master/pkg/keys/surface.asc \
    | gpg --dearmor | dd of=/etc/apt/trusted.gpg.d/linux-surface.gpg
    echo "✓ GPG key added"
else
    echo "✓ GPG key already exists"
fi

if [ ! -f /etc/apt/sources.list.d/linux-surface.list ]; then
    echo "deb [arch=amd64] https://pkg.surfacelinux.com/debian release main" \
    | tee /etc/apt/sources.list.d/linux-surface.list
    echo "✓ Repository added"
else
    echo "✓ Repository already exists"
fi

# Step 2: Update package lists
echo ""
echo "[2/8] Updating package lists..."
apt update

# Step 3: Install Surface kernel and dependencies
echo ""
echo "[3/8] Installing Surface kernel packages..."
apt install -y linux-image-surface linux-headers-surface libwacom-surface iptsd

# Step 4: Detect installed Surface kernel version
echo ""
echo "[4/8] Detecting installed Surface kernel..."
SURFACE_KERNEL=$(ls /boot/vmlinuz-*-surface* 2>/dev/null | sort -V | tail -1)
SURFACE_INITRD=$(ls /boot/initrd.img-*-surface* 2>/dev/null | sort -V | tail -1)

if [ -z "$SURFACE_KERNEL" ] || [ -z "$SURFACE_INITRD" ]; then
    echo "ERROR: Surface kernel not found in /boot/"
    exit 1
fi

KERNEL_VERSION=$(basename "$SURFACE_KERNEL" | sed 's/vmlinuz-//')
echo "✓ Found Surface kernel: $KERNEL_VERSION"

# Step 5: Copy kernel files to ESP
echo ""
echo "[5/8] Copying kernel files to ESP partition..."
cp "$SURFACE_KERNEL" "${ESP_DIR}/vmlinuz-surface.efi"
cp "$SURFACE_INITRD" "${ESP_DIR}/initrd-surface.img"
echo "✓ Kernel files copied"

# Step 6: Create boot entry
echo ""
echo "[6/8] Creating systemd-boot entry..."
BOOT_ENTRY="${ESP_PATH}/loader/entries/Pop_OS-surface.conf"

# Backup existing entry if it exists
if [ -f "$BOOT_ENTRY" ]; then
    cp "$BOOT_ENTRY" "${BOOT_ENTRY}.backup.$(date +%Y%m%d-%H%M%S)"
    echo "✓ Backed up existing boot entry"
fi

# Get current kernel options from Pop_OS-current.conf
CURRENT_OPTIONS=$(grep "^options" ${ESP_PATH}/loader/entries/Pop_OS-current.conf | sed 's/^options //')

# Create new boot entry
cat > "$BOOT_ENTRY" << EOF
title Pop!_OS Surface Kernel
linux /EFI/$(basename "$ESP_DIR")/vmlinuz-surface.efi
initrd /EFI/$(basename "$ESP_DIR")/initrd-surface.img
options root=UUID=${ROOT_UUID} ${CURRENT_OPTIONS}
EOF

echo "✓ Boot entry created: $BOOT_ENTRY"

# Step 7: Set as default boot entry
echo ""
echo "[7/8] Setting Surface kernel as default boot option..."
bootctl set-default Pop_OS-surface.conf
echo "✓ Default boot entry set"

# Step 8: Set up automatic updates
echo ""
echo "[8/8] Setting up automatic kernel updates..."

# Check if update-surface-kernel.sh exists in current directory
UPDATE_SCRIPT_SOURCE="$(dirname "$(readlink -f "$0")")/update-surface-kernel.sh"

if [ -f "$UPDATE_SCRIPT_SOURCE" ]; then
    # Copy update script to system path
    cp "$UPDATE_SCRIPT_SOURCE" /usr/local/bin/update-surface-kernel.sh
    chmod +x /usr/local/bin/update-surface-kernel.sh
    echo "✓ Update script installed to /usr/local/bin/"
    
    # Create APT hook
    cat > /etc/apt/apt.conf.d/90surface-kernel << 'EOF'
DPkg::Post-Invoke {
    "if [ -x /usr/local/bin/update-surface-kernel.sh ] && dpkg -l | grep -q linux-image-surface; then /usr/local/bin/update-surface-kernel.sh; fi";
};
EOF
    echo "✓ APT hook created - kernel will auto-update after apt upgrade"
else
    echo "⚠ Warning: update-surface-kernel.sh not found in script directory"
    echo "  Automatic updates not configured. You can set this up manually later."
fi

# Verify installation
echo ""
echo "=========================================="
echo "Surface Kernel Installation Complete!"
echo "=========================================="
echo ""
echo "Surface Kernel Version: $KERNEL_VERSION"
echo "Boot Entry: Pop_OS-surface.conf"
echo ""
echo "Current kernel: $(uname -r)"
echo ""
echo "Boot entries:"
bootctl list | grep -E "title:|id:|linux:|initrd:" | head -20
echo ""

# Step 9: Optional Howdy Installation
echo ""
echo "=========================================="
echo "Howdy Facial Recognition (Optional)"
echo "=========================================="
echo ""
echo "Surface devices have an IR camera that can be used for"
echo "Windows Hello-style facial recognition login with Howdy."
echo ""
echo "This will:"
echo "  - Install Howdy and face-recognition libraries"
echo "  - Configure the IR camera for facial recognition"
echo "  - Set up PAM for login with face + password fallback"
echo "  - Install safety features to prevent lockouts"
echo ""

HOWDY_SCRIPT="$(dirname "$(readlink -f "$0")")/install-howdy.sh"

if [ -f "$HOWDY_SCRIPT" ]; then
    read -p "Would you like to install Howdy facial recognition? (y/N): " INSTALL_HOWDY
    if [[ "$INSTALL_HOWDY" =~ ^[Yy]$ ]]; then
        echo ""
        echo "Starting Howdy installation..."
        echo ""
        bash "$HOWDY_SCRIPT"
    else
        echo ""
        echo "Skipping Howdy installation."
        echo "You can install it later by running: sudo ./install-howdy.sh"
    fi
else
    echo "⚠ Howdy installer not found at: $HOWDY_SCRIPT"
    echo "  You can install Howdy manually later."
fi

# Final summary
echo ""
echo "=========================================="
echo "Setup Complete!"
echo "=========================================="
echo ""
echo "Please reboot to start using the Surface kernel."
echo "After reboot, verify with: uname -r"
echo ""
echo "To reboot now, run: sudo reboot"