#!/bin/bash
# Howdy Pre-check Script
# Runs at boot before GDM starts
# Disables Howdy in every PAM file we manage if dependencies are missing
# This prevents login lockouts and broken sudo/polkit prompts

PAM_FILES=(
    "/etc/pam.d/gdm-password"
    "/etc/pam.d/polkit-1"
    "/etc/pam.d/sudo"
)
LOG_TAG="howdy-precheck"

log() {
    logger -t "$LOG_TAG" "$1"
}

if python3 -c "import face_recognition" 2>/dev/null; then
    log "Howdy dependencies OK - face_recognition available"
    exit 0
fi

log "WARNING: face_recognition not available - disabling Howdy in PAM"

for f in "${PAM_FILES[@]}"; do
    if [[ -f "$f" ]] && grep -q "^auth.*pam_python.so.*howdy" "$f"; then
        sed -i 's|^auth.*pam_python.so.*howdy.*|#DISABLED_MISSING_DEPS# &|' "$f"
        log "Howdy disabled in $f due to missing dependencies"
    fi
done

log "Re-run the Howdy installer to fix: sudo install-howdy.sh"
exit 0
