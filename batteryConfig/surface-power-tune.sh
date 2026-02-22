#!/bin/bash
# Surface Power Tuning Script
# Runs at boot to apply Surface-specific power optimizations
# Part of the Pop!_OS Surface Kernel battery optimization suite

LOG_TAG="surface-power-tune"

log() {
    logger -t "$LOG_TAG" "$1"
}

log "Applying Surface power optimizations..."

# 1. Disable USB wake devices (prevents phantom wakes from Surface Bluetooth adapter)
for device in /sys/bus/usb/devices/*/power/wakeup; do
    if [ -f "$device" ]; then
        echo "disabled" > "$device" 2>/dev/null || true
    fi
done
log "USB wake devices disabled"

# 2. Enable NVMe power saving (APST)
for nvme in /sys/class/nvme/nvme*/power/pm_qos_latency_tolerance_us; do
    if [ -f "$nvme" ]; then
        echo "any" > "$nvme" 2>/dev/null || true
    fi
done
log "NVMe power saving enabled"

# 3. Set PCI runtime PM to auto for all devices
for device in /sys/bus/pci/devices/*/power/control; do
    if [ -f "$device" ]; then
        echo "auto" > "$device" 2>/dev/null || true
    fi
done
log "PCI runtime PM set to auto"

# 4. Set SATA link power management
for policy in /sys/class/scsi_host/host*/link_power_management_policy; do
    if [ -f "$policy" ]; then
        echo "med_power_with_dipm" > "$policy" 2>/dev/null || true
    fi
done
log "SATA link power management set"

# 5. Enable audio codec power save
if [ -f /sys/module/snd_hda_intel/parameters/power_save ]; then
    echo 1 > /sys/module/snd_hda_intel/parameters/power_save 2>/dev/null || true
    log "Audio codec power save enabled"
fi

# 6. Disable bluetooth at boot if user opted in
if grep -q "DISABLE_BT_ON_BOOT=true" /etc/surface-power-tune.conf 2>/dev/null; then
    rfkill block bluetooth 2>/dev/null || true
    log "Bluetooth disabled per user preference"
fi

log "Surface power optimizations applied"
exit 0
