# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Surface Kernel Automation Suite for Pop!_OS. Automates installation, updating, and removal of the Linux Surface kernel on Pop!_OS systems (22.04+), with optional Howdy facial recognition for Surface IR cameras and battery optimization. All scripts require root/sudo and target Microsoft Surface hardware.

## Repository Structure

- **install-surface-kernel.sh** — 8-step kernel installer: adds linux-surface APT repo, installs kernel packages, configures systemd-boot (not GRUB), sets up APT hook for automatic updates, optionally triggers Howdy setup
- **update-surface-kernel.sh** — Detects new kernel versions, backs up current files, copies to ESP partition; re-asserts `Pop_OS-surface.conf` as the systemd-boot default on every run (Pop kernel updates run kernelstub, which steals the default back to `Pop_OS-current.conf`)
- **uninstall-surface-kernel.sh** — Removes boot entry, resets default kernel, cleans up APT hook, optionally removes packages
- **install-howdy.sh** — Standalone Howdy installer: IR camera detection, PAM configuration, safety service, face enrollment
- **uninstall-howdy.sh** — Disables Howdy PAM, removes safety service, optionally removes packages
- **howdyConfig/** — Systemd service (`howdy-check.service`), boot safety script (`howdy-precheck.sh`), diagnostic tool (`howdy-diagnose.py`), opt-in terminal face-auth wrapper (`sudof` + `howdy-trigger-check.sh` pam_exec gate)
- **install-battery.sh** — Battery optimization installer: auto-cpufreq, powertop auto-tune, Surface power tuning
- **uninstall-battery.sh** — Removes battery optimization services and optionally packages
- **batteryConfig/** — auto-cpufreq config, systemd services (`powertop-autotune.service`, `surface-power-tune.service`), Surface power tuning script

## Key Commands

```bash
# Install Surface kernel (main entry point)
sudo ./install-surface-kernel.sh

# Update kernel after apt upgrade
sudo ./update-surface-kernel.sh

# Remove Surface kernel
sudo ./uninstall-surface-kernel.sh

# Install/remove Howdy separately
sudo ./install-howdy.sh
sudo ./uninstall-howdy.sh

# Verify running kernel
uname -r    # should contain "surface"

# Howdy diagnostics
sudo python3 /usr/local/bin/howdy-diagnose.py

# Install/remove battery optimization separately
sudo ./install-battery.sh
sudo ./uninstall-battery.sh

# Check battery optimization status
sudo auto-cpufreq --stats
sudo powertop
```

## Architecture Details

**Boot Management:** Uses systemd-boot with ESP at `/boot/efi`. Boot entries go to `/boot/efi/loader/entries/Pop_OS-surface.conf`. Scripts detect and preserve existing Pop!_OS kernel parameters from the current boot entry.

**Automatic Updates:** The installer creates an APT hook at `/etc/apt/apt.conf.d/90surface-kernel` that triggers `update-surface-kernel.sh` (copied to `/usr/local/bin/`) after any `apt upgrade`.

**Howdy Safety System:** A systemd service (`howdy-check.service`) runs at boot to verify face_recognition dependencies. If missing, `howdy-precheck.sh` disables the Howdy PAM line in `/etc/pam.d/gdm-password` to prevent login lockouts. PAM is configured with `sufficient` mode so password fallback always works.

**Howdy PAM Integration:** Adds `auth sufficient pam_python.so /lib/security/howdy/pam.py` to `/etc/pam.d/gdm-password`. The 4-second timeout prevents hanging at login.

**Battery Optimization:** Three-layer approach: (1) auto-cpufreq dynamically manages CPU governor/turbo based on power source, (2) powertop auto-tune applies device power optimizations at boot via systemd oneshot service, (3) `surface-power-tune.sh` handles Surface-specific sysfs tuning (USB wake, NVMe APST, PCI runtime PM, SATA link power, audio codec). Config at `/etc/auto-cpufreq.conf`.

## Coding Conventions

- All bash scripts use `set -e` (exit on error)
- Root privilege check at the top of every script
- Status messages use `echo` with separator lines (`========`) for visual structure
- Scripts are self-contained — no shared library or sourced utilities between them
- Python diagnostic script (`howdy-diagnose.py`) uses only stdlib + `cv2`, `face_recognition`, `numpy`
- No build system, package manager lock files, or test framework — this is a pure shell/Python scripting project
