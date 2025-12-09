#!/bin/bash

# Howdy Facial Recognition Installation Script for Surface Devices
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
HOWDY_CONFIG_DIR="${SCRIPT_DIR}/howdyConfig"

# System paths
PAM_FILE="/etc/pam.d/gdm-password"
HOWDY_CONFIG="/lib/security/howdy/config.ini"
IR_CAMERA="/dev/video2"  # Default for Surface devices

echo ""
echo -e "${YELLOW}=========================================="
echo "Howdy Facial Recognition Installer"
echo "for Surface Devices on Pop!_OS"
echo -e "==========================================${NC}"
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    error "Please run as root (use sudo)"
    exit 1
fi

# Check if howdyConfig directory exists
if [[ ! -d "$HOWDY_CONFIG_DIR" ]]; then
    error "howdyConfig directory not found at: $HOWDY_CONFIG_DIR"
    error "Please ensure the script is in the correct location"
    exit 1
fi

# Step 1: Detect IR Camera
echo "[1/8] Detecting IR camera..."

# Find IR camera - Surface devices typically use video2
IR_FOUND=""
for dev in /dev/video0 /dev/video1 /dev/video2 /dev/video3; do
    if [[ -e "$dev" ]]; then
        CARD_TYPE=$(v4l2-ctl --device="$dev" --info 2>/dev/null | grep "Card type" | head -1 || true)
        if echo "$CARD_TYPE" | grep -qi "surface\|IR\|infrared"; then
            IR_FOUND="$dev"
            break
        fi
        # Check for greyscale format (typical for IR cameras)
        FORMATS=$(v4l2-ctl --device="$dev" --list-formats-ext 2>/dev/null || true)
        if echo "$FORMATS" | grep -qi "GREY\|greyscale"; then
            IR_FOUND="$dev"
            break
        fi
    fi
done

if [[ -n "$IR_FOUND" ]]; then
    IR_CAMERA="$IR_FOUND"
    success "Found IR camera at $IR_CAMERA"
else
    warn "Could not auto-detect IR camera, using default: $IR_CAMERA"
    if [[ ! -e "$IR_CAMERA" ]]; then
        error "Default camera $IR_CAMERA does not exist!"
        echo "Available video devices:"
        ls -la /dev/video* 2>/dev/null || echo "  None found"
        echo ""
        read -p "Enter the correct IR camera device path (or press Enter to abort): " CUSTOM_CAM
        if [[ -z "$CUSTOM_CAM" ]]; then
            error "No camera specified. Aborting."
            exit 1
        fi
        IR_CAMERA="$CUSTOM_CAM"
    fi
fi

# Step 2: Install Howdy package
echo ""
echo "[2/8] Installing Howdy package..."

if dpkg -l | grep -q "^ii.*howdy"; then
    success "Howdy already installed"
else
    apt update
    apt install -y howdy
    success "Howdy installed"
fi

# Step 3: Install face-recognition Python library
echo ""
echo "[3/8] Installing face-recognition library..."

# Check current state
echo "Checking Python packages:"
pip3 show face-recognition >/dev/null 2>&1 && echo "  face-recognition: installed" || echo "  face-recognition: MISSING"
pip3 show dlib >/dev/null 2>&1 && echo "  dlib: installed" || echo "  dlib: MISSING"

if ! pip3 show face-recognition >/dev/null 2>&1; then
    log "Installing face-recognition (this may take several minutes)..."

    # Install build dependencies
    apt install -y cmake libopenblas-dev liblapack-dev python3-pip

    # Install face_recognition
    pip3 install face_recognition
    success "face-recognition installed"
else
    success "face-recognition already installed"
fi

# Step 4: Configure Howdy for Surface
echo ""
echo "[4/8] Configuring Howdy for Surface device..."

if [[ -f "$HOWDY_CONFIG" ]]; then
    # Backup original config
    cp "$HOWDY_CONFIG" "${HOWDY_CONFIG}.backup.$(date +%Y%m%d_%H%M%S)"

    # Set device path
    sed -i "s|^device_path.*|device_path = $IR_CAMERA|" "$HOWDY_CONFIG"

    # Set timeout (4 seconds - enough time but not too long)
    sed -i 's/^timeout.*/timeout = 4/' "$HOWDY_CONFIG"

    # Set certainty (4.5 is a good balance for Surface IR cameras)
    sed -i 's/^certainty.*/certainty = 4.5/' "$HOWDY_CONFIG"

    # Set dark threshold
    sed -i 's/^dark_threshold.*/dark_threshold = 50/' "$HOWDY_CONFIG"

    # Disable detection notice (cleaner login)
    sed -i 's/^detection_notice.*/detection_notice = false/' "$HOWDY_CONFIG"

    # Enable lid closed detection (important for laptops)
    sed -i 's/^ignore_closed_lid.*/ignore_closed_lid = true/' "$HOWDY_CONFIG"

    success "Howdy configured for Surface"
    echo "  Device: $IR_CAMERA"
    echo "  Timeout: 4 seconds"
    echo "  Certainty: 4.5"
else
    error "Howdy config not found at $HOWDY_CONFIG"
    error "Howdy may not be installed correctly"
    exit 1
fi

# Step 5: Configure PAM for GDM
echo ""
echo "[5/8] Configuring PAM for facial recognition login..."

if [[ -f "$PAM_FILE" ]]; then
    # Backup PAM file
    cp "$PAM_FILE" "${PAM_FILE}.backup.$(date +%Y%m%d_%H%M%S)"

    # Remove any existing howdy lines to avoid duplicates
    sed -i '/pam_python.so.*howdy/d' "$PAM_FILE"

    # Add howdy line before @include common-auth
    # Using 'sufficient' means: if howdy succeeds, auth passes
    # If howdy fails/times out, it falls through to password
    if grep -q "@include common-auth" "$PAM_FILE"; then
        sed -i '/@include common-auth/i auth sufficient pam_python.so /lib/security/howdy/pam.py' "$PAM_FILE"
        success "PAM configured with password fallback"
    else
        warn "Could not find @include common-auth in PAM file"
        warn "You may need to configure PAM manually"
    fi
else
    error "PAM file not found at $PAM_FILE"
    exit 1
fi

# Step 6: Install safety service
echo ""
echo "[6/8] Installing boot-time safety service..."

# Copy precheck script
cp "${HOWDY_CONFIG_DIR}/howdy-precheck.sh" /usr/local/bin/
chmod +x /usr/local/bin/howdy-precheck.sh

# Copy systemd service
cp "${HOWDY_CONFIG_DIR}/howdy-check.service" /etc/systemd/system/
chmod 644 /etc/systemd/system/howdy-check.service

# Enable the service
systemctl daemon-reload
systemctl enable howdy-check.service

success "Safety service installed"
echo "  This prevents login lockouts if dependencies break"

# Step 7: Copy diagnostic tool
echo ""
echo "[7/8] Installing diagnostic tools..."

cp "${HOWDY_CONFIG_DIR}/howdy-diagnose.py" /usr/local/bin/
chmod +x /usr/local/bin/howdy-diagnose.py

success "Diagnostic tools installed"
echo "  Run 'sudo python3 /usr/local/bin/howdy-diagnose.py' to troubleshoot"

# Step 8: Add face model
echo ""
echo "[8/8] Adding your face model..."
echo ""
echo -e "${YELLOW}You need to add your face to Howdy for recognition to work.${NC}"
echo ""
echo "Tips for best results:"
echo "  - Look directly at the camera (above the screen)"
echo "  - Ensure good lighting"
echo "  - Add multiple models from different angles"
echo ""

read -p "Add your face now? (Y/n): " ADD_FACE
if [[ ! "$ADD_FACE" =~ ^[Nn]$ ]]; then
    echo ""
    echo "Adding face model 'main'..."
    echo "Look at the IR camera when the window opens."
    echo ""

    if howdy add -l main; then
        success "Face model added!"

        echo ""
        read -p "Add another angle for better recognition? (y/N): " ADD_MORE
        if [[ "$ADD_MORE" =~ ^[Yy]$ ]]; then
            echo "Turn your head slightly to the left..."
            howdy add -l left || true
            echo "Turn your head slightly to the right..."
            howdy add -l right || true
        fi
    else
        warn "Failed to add face model"
        echo "You can add it later with: sudo howdy add"
    fi
else
    echo ""
    echo "You can add your face later with: sudo howdy add"
fi

# Final summary
echo ""
echo -e "${GREEN}=========================================="
echo "Howdy Installation Complete!"
echo -e "==========================================${NC}"
echo ""
echo "Configuration:"
echo "  IR Camera: $IR_CAMERA"
echo "  Timeout: 4 seconds"
echo "  Certainty: 4.5 (1-10 scale, lower = stricter)"
echo ""
echo "How it works:"
echo "  1. At login, Howdy tries facial recognition for 4 seconds"
echo "  2. If recognized, you're logged in automatically"
echo "  3. If not recognized or timeout, password prompt appears"
echo ""
echo "Useful commands:"
echo "  sudo howdy add         - Add another face model"
echo "  sudo howdy list        - List saved face models"
echo "  sudo howdy remove      - Remove a face model"
echo "  sudo howdy test        - Test camera and detection"
echo "  sudo howdy config      - Edit configuration"
echo ""
echo "Safety features enabled:"
echo "  - Password fallback on recognition failure"
echo "  - Boot-time dependency check"
echo "  - 4-second timeout prevents hanging"
echo ""

# Verify with a test if user wants
read -p "Run a quick test to verify Howdy works? (Y/n): " RUN_TEST
if [[ ! "$RUN_TEST" =~ ^[Nn]$ ]]; then
    echo ""
    echo "Running Howdy test - look at the camera..."
    echo "Press Ctrl+C to close the test window when done."
    echo ""
    howdy test || warn "Test cancelled or failed"
fi

echo ""
echo -e "${GREEN}Howdy is ready! It will activate on your next login.${NC}"
echo ""
