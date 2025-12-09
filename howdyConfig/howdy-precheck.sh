#!/bin/bash
# Howdy Pre-check Script
# Runs at boot before GDM starts
# Disables Howdy in PAM if dependencies are missing
# This prevents login lockouts

PAM_FILE="/etc/pam.d/gdm-password"
LOG_TAG="howdy-precheck"

log() {
    logger -t "$LOG_TAG" "$1"
}

# Check if face_recognition is importable
if python3 -c "import face_recognition" 2>/dev/null; then
    log "Howdy dependencies OK - face_recognition available"
    exit 0
else
    log "WARNING: face_recognition not available - disabling Howdy in PAM"

    # Disable howdy in PAM to prevent lockout
    if [[ -f "$PAM_FILE" ]] && grep -q "^auth.*pam_python.so.*howdy" "$PAM_FILE"; then
        sed -i 's/^auth.*sufficient.*pam_python.so.*howdy/#DISABLED_MISSING_DEPS# &/' "$PAM_FILE"
        log "Howdy disabled in $PAM_FILE due to missing dependencies"
        log "Re-run the Howdy installer to fix: sudo install-howdy.sh"
    fi

    exit 0
fi
