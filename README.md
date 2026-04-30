# OpenWrt Cloudflare Tunnel Installer and Uninstaller v2026.4.1

Scripts to install, configure and uninstall Cloudflare Tunnels on OpenWrt, for arm based routers (GL.iNet GL-MT6000), Raspberry Pi and x86 platforms. Downloads cloudflared directly from GitHub and handles tunnel setup and service configuration.

## What's included
1. **`install-cloudflared.sh`** – Downloads cloudflared, walks through tunnel setup (local or web-managed), sets up the init.d service, and installs an updater with optional daily cron.
2. **`uninstall-cloudflared.sh`** – Removes everything: service, binary, updater, configs, and cron job.

## Prerequisites
- Raspberry Pi or x86 running OpenWrt 24.10+ (opkg) or 25.12+ (apk)
- Root access
- Internet connection

## Getting Started
```bash
git clone https://github.com/Coralesoft/OpenwrtCloudflare.git
cd OpenwrtCloudflare
```

## Installation

### Quick Start
```bash
chmod +x install-cloudflared.sh && sudo ./install-cloudflared.sh
```

### Or step by step
1. Download the installer:
   ```bash
   wget https://raw.githubusercontent.com/Coralesoft/OpenwrtCloudflare/main/install-cloudflared.sh
   ```
2. Make it executable:
   ```bash
   chmod +x install-cloudflared.sh
   ```
3. Run it:
   ```bash
   sudo ./install-cloudflared.sh
   ```
4. Follow the prompts – pick local or web-managed, enter your tunnel details, optionally enable daily auto-updates.

## Uninstallation

### Quick Start
```bash
chmod +x uninstall-cloudflared.sh && sudo ./uninstall-cloudflared.sh
```

### Or step by step
1. Download the uninstaller:
   ```bash
   wget https://raw.githubusercontent.com/Coralesoft/OpenwrtCloudflare/main/uninstall-cloudflared.sh
   ```
2. Make it executable:
   ```bash
   chmod +x uninstall-cloudflared.sh
   ```
3. Run it:
   ```bash
   sudo ./uninstall-cloudflared.sh
   ```

## Updating

### Automatic
If you enabled the cron job during install, cloudflared is checked daily at 12:30 and updated if a new release is out.

### Manual
```bash
/usr/sbin/cloudflared-update
```

## Troubleshooting
- **Not enough space** – Installer checks for ~65 MB free and will tell you if there isn't enough.
- **Unsupported architecture** – Only aarch64 and x86_64 are supported.
- **Permission errors** – Run as root.
- **Install fails halfway through** – The installer rolls back automatically.

## Support
For issues or feature requests, contact **C. Brown** at [dev@coralesoft.nz](mailto:dev@coralesoft.nz).

## Support the Project
If you find this useful, consider buying me a coffee:

<a href="https://www.buymeacoffee.com/r6zt79njh5m" target="_blank">
  <img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" alt="Buy Me A Coffee" style="height:60px;width:217px;" />
</a>

## License
MIT License – see `LICENSE` for details.

## Acknowledgements
Thanks to the OpenWrt and Cloudflare communities for their tools and documentation.
