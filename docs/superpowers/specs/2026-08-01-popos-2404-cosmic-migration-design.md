# Pop!_OS 22.04 → 24.04 COSMIC Migration Design

**Date:** 2026-08-01
**Machine:** Microsoft Surface laptop (Tiger Lake, Intel Iris Xe), single NVMe, no separate /home partition
**Decision:** In-place upgrade via `pop-upgrade`, full NAS backup first, dock quirks triaged post-upgrade

## Goals

Migrate this machine from Pop!_OS 22.04 (GNOME/X11) to Pop!_OS 24.04 (COSMIC/Wayland) while preserving user data and restoring the full hardware stack: Surface kernel (touchscreen/pen/IR camera), DisplayLink dock (HP USB-C/A Universal Dock G2, 2×2560x1440), and — where feasible — Howdy facial login.

## Non-goals

- Fresh install (rejected: no separate /home; in-place is now the official supported path)
- Pre-upgrade live-USB validation (user accepted post-upgrade triage instead)
- Keeping GNOME or any X11 session on 24.04 (COSMIC is Wayland-only; X11 apps run under XWayland)

## Constraints and known risks

1. **The upgrade removes all PPAs and third-party apt repos** (linux-surface, Howdy PPA, docker, vscode, nodesource, …). Installed packages remain but stop updating; repos must be re-added afterward from a captured manifest.
2. **Dangling PAM lines are a lockout risk.** Howdy's PAM entries in `gdm-password`, `polkit-1`, and `sudo` reference `pam_python.so` from PPA packages. These must be stripped (via `uninstall-howdy.sh`) before upgrading.
3. **DisplayLink under COSMIC works but has open upstream bugs** (as of 2026-06): cursor stutter on dock outputs (cosmic-comp#2443), boot-with-dock-attached failures (cosmic-epoch#2380), multi-monitor dock dropouts (cosmic-epoch#2445). The Feb 2026 high-CPU fix (cosmic-comp#2109) is merged. Accepted risk; triage after.
4. **Howdy on cosmic-greeter is unproven.** GDM is replaced by cosmic-greeter (different PAM file). Howdy PPA availability for 24.04 and Howdy 3.x's new PAM module must be verified post-upgrade. Treated as experimental; fallback is password-only login.
5. **Boot management carries over:** 24.04 still uses systemd-boot + kernelstub, so this repo's scripts (lowercase `set-default`, self-healing APT hook) apply with minor changes.

## Phase 1 — Pre-upgrade safety

- rsync backup over SSH to the user's NAS (host/path collected at execution time):
  - `/home` (excluding caches), `/etc` in full, docker volumes (`docker volume ls` + tar of `/var/lib/docker/volumes`), Howdy face models (`/lib/security/howdy/` models + config)
  - Manifests: `dpkg -l`, `apt-mark showmanual`, contents of `/etc/apt/sources.list.d/`, `bootctl list`, `xrandr --query`, enabled GNOME extensions (for reference only)
- Spot-check the backup (restore a sample file, compare sizes) before proceeding
- Run `uninstall-howdy.sh` to strip all Howdy PAM integration (keeps face models on disk via backup)
- `bootctl set-default pop_os-current.conf` so the upgrade and first boots run on the stock Pop kernel (touchscreen temporarily lost — expected)
- Ensure ≥20 GB free disk space and AC power

## Phase 2 — The upgrade

- `pop-upgrade release upgrade` (CLI) or Settings → OS Upgrade & Recovery
- Expect: GNOME → COSMIC, PPA removal, application re-pinning needed, 1–2 h duration
- First boot lands in cosmic-greeter on the stock Pop kernel with Intel graphics — the safest possible configuration

## Phase 3 — Post-upgrade restoration (dependency order)

1. Re-add third-party repos from the manifest; `apt update && apt full-upgrade`; reinstall repo-sourced apps (docker, vscode, etc.)
2. Re-add linux-surface repo; run this repo's `install-surface-kernel.sh` (review first against 24.04 — expected compatible); reboot; verify `uname -r` shows surface kernel, then touchscreen, pen, IR camera nodes
3. Reinstall DisplayLink driver (Synaptics 24.04/noble build); verify DKMS builds evdi for the surface kernel; run `depmod -a` if modprobe fails (known issue, documented in README); re-apply `initial_device_count=0` in `/etc/modprobe.d/evdi.conf`; test dock outputs under COSMIC
4. Howdy (experimental): verify PPA has 24.04 packages; if yes, port `install-howdy.sh` to target `/etc/pam.d/cosmic-greeter` instead of `gdm-password`; restore face models from backup; keep the precheck safety service pattern. If no viable packages: defer, password login until upstream support lands.
5. COSMIC configuration: native tiling replaces pop-shell; blur-my-shell is obsolete (stays gone); re-pin dock/panel applications

## Phase 4 — Repo updates

- Adapt scripts for 24.04 as changes are discovered (cosmic-greeter PAM target, README compatibility notes); commit and push each logical fix, as done for the 2026-07-30/31 fixes

## Phase 5 — Rollback

- Hard failure during upgrade: boot recovery partition → reinstall → restore from NAS backup
- Soft failure (COSMIC unusable for daily work): data is intact; fixes applied incrementally; last resort is recovery reinstall of 22.04 + NAS restore

## Verification checklist (post-migration definition of done)

- [ ] Boots to cosmic-greeter, login works
- [ ] `uname -r` = surface kernel; touchscreen, pen work
- [ ] IR camera nodes present (`/dev/video*` shows Surface IR)
- [ ] Wi-Fi, Bluetooth, audio work
- [ ] Home dock: both 2560x1440 outputs light up under COSMIC; USB/Ethernet/audio through dock work
- [ ] Docker: containers and volumes intact
- [ ] Dev tooling: vscode, node, git, claude code functional
- [ ] Howdy: working on cosmic-greeter, or consciously deferred
- [ ] Surface repo scripts updated for 24.04 and pushed
