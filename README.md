# OpenWrt Cloudflare Tunnel Installer and Uninstaller v2025.6.1

Welcome to the **OpenWrt Cloudflare Tunnel Installer and Uninstaller** project! This repository contains scripts that automate installation, configuration and uninstallation of Cloudflare Tunnels on OpenWrt systems, suitable for both Raspberry Pi and x86 platforms.

## Overview
This repository includes:
1. **`install-cloudflared.sh`** – Installs Cloudflared, guides through tunnel setup (local or web-managed), configures as an init.d service, installs updater and optionally schedules daily updates.
2. **`uninstall-cloudflared.sh`** – Reverses all changes: stops & disables service, removes binaries, configs, updater and cron jobs.

## Prerequisites
- **Compatible Hardware**: Raspberry Pi or x86 devices running OpenWrt.  
- **Administrative Access**: Must run as root (installer enforces UID 0).  
- **Internet**: Required to download binaries and updates.

## Getting Started
Clone the repo to your device:
```bash
git clone https://github.com/Coralesoft/OpenwrtCloudflare.git
cd OpenwrtCloudflare
```

## Installation

### Quick Start Command
```bash
chmod +x install-cloudflared.sh && sudo ./install-cloudflared.sh
```

### Step-by-Step Instructions
1. **Download** the installer:
   ```bash
   wget https://raw.githubusercontent.com/Coralesoft/OpenwrtCloudflare/main/install-cloudflared.sh
   ```
2. **Make executable**:
   ```bash
   chmod +x install-cloudflared.sh
   ```
3. **Run** the installer:
   ```bash
   sudo ./install-cloudflared.sh
   ```
4. **Follow prompts**:
   - Choose local or web-managed tunnel.
   - Enter tunnel name and domain or paste token.
   - Opt in for cron-based auto-updates if desired.

## Uninstallation

### Quick Start Command
```bash
chmod +x uninstall-cloudflared.sh && sudo ./uninstall-cloudflared.sh
```

### Step-by-Step Instructions
1. **Download** the uninstaller (if not present):
   ```bash
   wget https://raw.githubusercontent.com/Coralesoft/OpenwrtCloudflare/main/uninstall-cloudflared.sh
   ```
2. **Make executable**:
   ```bash
   chmod +x uninstall-cloudflared.sh
   ```
3. **Run** the uninstaller:
   ```bash
   sudo ./uninstall-cloudflared.sh
   ```
4. **Verify removal**: No `cloudflared` service, binary or configs should remain.

## Updating

### Automatic Updates
If auto-updates were enabled, a daily cron job at 12:30 will run `/usr/sbin/cloudflared-update`.

### Manual Update
Run on demand:
```bash
/usr/sbin/cloudflared-update
```
This will:
1. Check the latest release on GitHub.  
2. Compare to your installed version.  
3. Download and replace if newer.  
4. Restart the `cloudflared` service.  

## Troubleshooting
- **Insufficient space**: Installer will exit with a message.  
- **Unsupported architecture**: Only `aarch64` and `x86_64` are supported.  
- **Permission errors**: Ensure you run as root.  
- **Rollback**: On error, installer cleans up all changes.  

## Support
For issues or feature requests, contact **C. Brown** at [dev@coralesoft.nz](mailto:dev@coralesoft.nz).

## Support the Project
If this project helps you streamline your OpenWrt setup and you’d like to support ongoing development, consider buying me a coffee. Your contribution keeps the creativity flowing and helps sustain future updates.

<a href="https://www.buymeacoffee.com/r6zt79njh5m" target="_blank">
  <img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" alt="Buy Me A Coffee" style="height:60px;width:217px;" />
</a>

## License
MIT License – see `LICENSE` for details.

## Acknowledgements
Thanks to the OpenWrt and Cloudflare communities for their tools and documentation.
