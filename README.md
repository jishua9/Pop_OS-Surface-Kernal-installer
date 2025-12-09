# Surface Kernel & Howdy Automation Scripts for Pop!_OS

These scripts automate the installation, updating, and removal of the Linux Surface kernel on Pop!_OS systems, including optional Howdy facial recognition setup.

## Scripts Included

### Kernel Scripts
1. **install-surface-kernel.sh** - Initial installation script (includes optional Howdy setup)
2. **update-surface-kernel.sh** - Update script for kernel upgrades
3. **uninstall-surface-kernel.sh** - Remove Surface kernel and revert to Pop!_OS kernel

### Howdy Facial Recognition Scripts
4. **install-howdy.sh** - Standalone Howdy installer for Surface IR cameras
5. **uninstall-howdy.sh** - Remove Howdy and restore password-only login
6. **howdyConfig/** - Configuration files and safety services

## Prerequisites

- Pop!_OS 22.04 or later
- Internet connection
- Root/sudo access
- Surface device (Laptop, Pro, Book, etc.)

## Installation

### First Time Setup

1. Download all scripts to your system
2. Make them executable:
```bash
chmod +x install-surface-kernel.sh update-surface-kernel.sh uninstall-surface-kernel.sh
```

3. Run the installation script:
```bash
sudo ./install-surface-kernel.sh
```

4. Reboot when prompted:
```bash
sudo reboot
```

5. Verify you're running the Surface kernel:
```bash
uname -r
```
You should see "surface" in the output.

## Usage

### Installing Surface Kernel (First Time)

```bash
sudo ./install-surface-kernel.sh
```

This script will:
- Add the Linux Surface repository
- Install the Surface kernel and dependencies (iptsd, libwacom-surface)
- Configure systemd-boot to use the Surface kernel
- Set it as the default boot option
- **Set up automatic kernel updates (via APT hook)**

### Updating Surface Kernel

After running `sudo apt update && sudo apt upgrade`, if the Surface kernel is updated:

```bash
sudo ./update-surface-kernel.sh
```

This script will:
- Detect the latest Surface kernel
- Backup the current kernel files
- Copy new kernel files to the ESP partition
- Prompt you to reboot

### Uninstalling Surface Kernel

To revert back to the Pop!_OS kernel:

```bash
sudo ./uninstall-surface-kernel.sh
```

This script will:
- Remove the Surface kernel boot entry
- Set the default Pop!_OS kernel as default
- Remove automatic update configuration (APT hook and update script)
- Optionally remove Surface kernel packages

## What Gets Fixed

Installing the Surface kernel fixes these hardware issues:

- ✓ Trackpad right-click (two-finger tap)
- ✓ Touch screen support
- ✓ Pen/stylus input
- ✓ Better battery management
- ✓ Improved suspend/resume
- ✓ Better thermal management
- ✓ Surface-specific hardware quirks
- ✓ IR camera support (for Howdy facial recognition)

## Howdy Facial Recognition

Surface devices include an IR camera that enables Windows Hello-style facial recognition. Howdy brings this feature to Linux.

### Installing Howdy

Howdy installation is offered automatically at the end of the kernel installation. You can also install it separately:

```bash
sudo ./install-howdy.sh
```

This will:
1. Install Howdy and the face-recognition Python library
2. Auto-detect your Surface IR camera
3. Configure optimal settings for Surface devices
4. Set up PAM for facial recognition with password fallback
5. Install a boot-time safety service to prevent lockouts
6. Guide you through adding your face model

### How Howdy Works

1. At the login screen, the IR camera activates
2. Howdy attempts facial recognition for 4 seconds
3. If your face is recognized, you're logged in automatically
4. If not recognized or timeout, password prompt appears

### Howdy Commands

```bash
sudo howdy add              # Add a new face model
sudo howdy add -l office    # Add face model with label
sudo howdy list             # List saved face models
sudo howdy remove           # Remove a face model
sudo howdy test             # Test camera and face detection
sudo howdy config           # Edit Howdy configuration
```

### Adding Multiple Face Models

For better recognition in different conditions, add multiple face models:

```bash
sudo howdy add -l front     # Looking straight ahead
sudo howdy add -l left      # Slight turn left
sudo howdy add -l right     # Slight turn right
sudo howdy add -l glasses   # With glasses on/off
```

### Howdy Configuration

Default settings optimized for Surface devices:
- **Device**: `/dev/video2` (IR camera)
- **Timeout**: 4 seconds
- **Certainty**: 4.5 (1-10 scale, lower = stricter)

To adjust settings:
```bash
sudo howdy config
```

### Troubleshooting Howdy

**Face not recognized:**
- Add more face models from different angles
- Increase certainty value (e.g., 5.0 or 5.5)
- Ensure good lighting

**Howdy hangs at login:**
- The safety service should prevent this
- If stuck, press Ctrl+Alt+F3 for TTY, login, and run:
  ```bash
  sudo sed -i '/pam_python.so.*howdy/d' /etc/pam.d/gdm-password
  ```

**Run diagnostics:**
```bash
sudo python3 /usr/local/bin/howdy-diagnose.py
```

### Uninstalling Howdy

```bash
sudo ./uninstall-howdy.sh
```

Or remove during kernel uninstallation (you'll be prompted).

## Automation Options

### Automatic Updates

**Good news!** The installation script automatically sets up the APT hook for you. After running the installer, your Surface kernel will automatically update its boot files whenever you run `apt upgrade` and a new Surface kernel is available.

If you need to set this up manually (or on a system where you didn't use the installer), here's how:

#### Option 1: APT Hook

Create `/etc/apt/apt.conf.d/90surface-kernel`:

```
DPkg::Post-Invoke {
    "if [ -x /usr/local/bin/update-surface-kernel.sh ] && dpkg -l | grep -q linux-image-surface; then /usr/local/bin/update-surface-kernel.sh; fi";
};
```

Copy the update script to system path:
```bash
sudo cp update-surface-kernel.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/update-surface-kernel.sh
```

#### Option 2: Manual Check After Updates

Simply remember to run the update script after `apt upgrade` shows a Surface kernel update.

### What Happens During Automatic Updates

When you run `sudo apt upgrade` and the Surface kernel gets updated, you'll see:

```
...
Unpacking linux-image-surface ...
Setting up linux-image-surface ...
...
========================================
Surface Kernel Updater for Pop!_OS
========================================

Detecting system configuration...
ESP Directory: /boot/efi/EFI/Pop_OS-xxxxx
Currently running: 6.17.1-surface-2
Latest Surface kernel: 6.17.2-surface-1

Backing up current Surface kernel files...
✓ Backup complete

Updating kernel files in ESP partition...
✓ Kernel files updated

========================================
Update Complete!
========================================

Updated to: 6.17.2-surface-1
Currently running: 6.17.1-surface-2

Please reboot to use the new kernel.
```

Just reboot when convenient, and you'll be on the new kernel!

## Troubleshooting

### Boot Issues

If you can't boot after installation:

1. At boot, hold SPACE to show the boot menu
2. Select "Pop!_OS (Pop_OS-current.conf)" to use the default kernel
3. Run the uninstall script to revert changes

### Kernel Not Showing Up

Check if the kernel is installed:
```bash
ls /boot/vmlinuz-*-surface*
```

Check boot entries:
```bash
sudo bootctl list
```

### Trackpad Still Not Working

Make sure you're actually running the Surface kernel:
```bash
uname -r
```

If it shows the Surface kernel but trackpad doesn't work, you may need to add modules to initramfs. Check the Surface Linux wiki for device-specific notes.

## Additional Resources

- [Linux Surface GitHub](https://github.com/linux-surface/linux-surface)
- [Surface Linux Wiki](https://github.com/linux-surface/linux-surface/wiki)
- [Device-Specific Notes](https://github.com/linux-surface/linux-surface/wiki/Supported-Devices-and-Features)

## Support

For issues specific to these scripts, check the script output for error messages.

For Surface kernel issues, visit the [Linux Surface GitHub Issues](https://github.com/linux-surface/linux-surface/issues).

## License

These scripts are provided as-is for use with Pop!_OS and Surface devices.

## Credits

- Linux Surface project: https://github.com/linux-surface/linux-surface
- Pop!_OS by System76: https://pop.system76.com/