#!/bin/bash

# Howdy Facial Recognition Uninstaller for Surface Devices
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

PAM_FILE="/etc/pam.d/gdm-password"

echo ""
echo -e "${YELLOW}=========================================="
echo "Howdy Facial Recognition Uninstaller"
echo -e "==========================================${NC}"
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    error "Please run as root (use sudo)"
    exit 1
fi

echo "This will:"
echo "  1. Disable Howdy in PAM (restore password-only login)"
echo "  2. Remove the boot-time safety service"
echo "  3. Optionally remove Howdy package and face models"
echo ""
read -p "Do you want to continue? (y/N): " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 0
fi

# Step 1: Disable Howdy in PAM
echo ""
echo "[1/4] Disabling Howdy in PAM..."

if [[ -f "$PAM_FILE" ]]; then
    # Backup PAM file
    cp "$PAM_FILE" "${PAM_FILE}.backup.$(date +%Y%m%d_%H%M%S)"

    # Remove howdy line
    if grep -q "pam_python.so.*howdy" "$PAM_FILE"; then
        sed -i '/pam_python.so.*howdy/d' "$PAM_FILE"
        success "Howdy removed from PAM - password login restored"
    else
        success "Howdy was not enabled in PAM"
    fi
else
    warn "PAM file not found at $PAM_FILE"
fi

# Step 2: Remove safety service
echo ""
echo "[2/4] Removing boot-time safety service..."

if systemctl is-enabled howdy-check.service >/dev/null 2>&1; then
    systemctl disable howdy-check.service
    success "Safety service disabled"
else
    success "Safety service was not enabled"
fi

if [[ -f /etc/systemd/system/howdy-check.service ]]; then
    rm /etc/systemd/system/howdy-check.service
    systemctl daemon-reload
    success "Safety service removed"
fi

if [[ -f /usr/local/bin/howdy-precheck.sh ]]; then
    rm /usr/local/bin/howdy-precheck.sh
    success "Precheck script removed"
fi

# Step 3: Remove diagnostic tools
echo ""
echo "[3/4] Removing diagnostic tools..."

if [[ -f /usr/local/bin/howdy-diagnose.py ]]; then
    rm /usr/local/bin/howdy-diagnose.py
    success "Diagnostic tools removed"
else
    success "Diagnostic tools were not installed"
fi

# Step 4: Optionally remove Howdy package
echo ""
echo "[4/4] Remove Howdy package and face models?"
echo ""
echo "If you keep Howdy installed, you can easily re-enable it later."
echo "Removing it will also delete your saved face models."
echo ""
read -p "Remove Howdy package completely? (y/N): " REMOVE_PKG

if [[ "$REMOVE_PKG" =~ ^[Yy]$ ]]; then
    log "Removing Howdy package..."
    apt remove --purge -y howdy || warn "Could not remove howdy package"
    success "Howdy package removed"

    # Also remove face-recognition if user wants
    echo ""
    read -p "Also remove face-recognition Python library? (y/N): " REMOVE_FACERECOG
    if [[ "$REMOVE_FACERECOG" =~ ^[Yy]$ ]]; then
        pip3 uninstall -y face_recognition || warn "Could not remove face_recognition"
        success "face-recognition removed"
    fi
else
    success "Howdy package kept"
    echo "  You can remove it later with: sudo apt remove howdy"
fi

# Summary
echo ""
echo -e "${GREEN}=========================================="
echo "Howdy Uninstallation Complete!"
echo -e "==========================================${NC}"
echo ""
echo "Changes made:"
echo "  - Howdy disabled in PAM (password login only)"
echo "  - Boot-time safety service removed"
echo "  - Diagnostic tools removed"
if [[ "$REMOVE_PKG" =~ ^[Yy]$ ]]; then
    echo "  - Howdy package removed"
fi
echo ""
echo "Your system will now use password-only authentication."
echo ""
