
# OpenWrt Cloudflare Tunnel Installer and Uninstaller

Welcome to the **OpenWrt Cloudflare Tunnel Installer and Uninstaller** project! This repository contains scripts that facilitate the installation and removal of Cloudflare Tunnels on OpenWrt systems, suitable for both Raspberry Pi and x86 platforms.

## Overview
This repository includes:
1. **`install-cloudflared.sh`**: A script to install the Cloudflare Tunnel service on your OpenWrt system.
2. **`uninstall-cloudflared.sh`**: A script to uninstall and clean up the Cloudflare Tunnel service from your OpenWrt system.

## Prerequisites
- **Compatible Hardware**: Raspberry Pi or x86 devices running OpenWrt.
- **Administrative Access**: You need to have root access on your device to run these scripts.

## Getting Started
To clone this repository to your OpenWrt device:
```bash
git clone https://github.com/Coralesoft/OpenwrtCloudflare.git
cd OpenwrtCloudflare
```

### Installation
#### Quick Start Command
To install Cloudflare Tunnel directly, execute the following command:
```bash
git clone https://github.com/Coralesoft/OpenwrtCloudflare.git && cd OpenwrtCloudflare && chmod +x install-cloudflared.sh && ./install-cloudflared.sh
```
#### Step-by-Step Instructions
1. Download the installation script:
    ```bash
    wget https://raw.githubusercontent.com/Coralesoft/OpenwrtCloudflare/main/install-cloudflared.sh
    ```
2. Make the script executable:
    ```bash
    chmod +x install-cloudflared.sh
    ```
3. Run the script:
    ```bash
    ./install-cloudflared.sh
    ```

### Uninstallation
#### Quick Start Command
To uninstall the Cloudflare Tunnel directly, execute the following commands:
```bash
cd OpenwrtCloudflare && chmod +x uninstall-cloudflared.sh && ./uninstall-cloudflared.sh
```
#### Step-by-Step Instructions
1. Make the uninstall script executable:
    ```bash
    chmod +x uninstall-cloudflared.sh
    ```
2. Run the uninstall script:
    ```bash
    ./uninstall-cloudflared.sh
    ```

## Troubleshooting
If you encounter issues such as insufficient disk space or missing tools, the installation script attempts to address these automatically. For more complex issues, you may need to manually intervene.

## Support
For support or further assistance, contact **C. Brown** at [dev@coralesoft.nz](mailto:dev@coralesoft.nz).

## License
This project is licensed under the MIT License. See the `LICENSE` file in the repository for more details.


## Support the Project

If this project helps you streamline your OpenWrt setup and you want to support my ongoing work, consider buying me a coffee. Your generous contribution keeps the creativity flowing and helps sustain future development. Thanks for supporting!

<a href="https://www.buymeacoffee.com/r6zt79njh5m" target="_blank"> <img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" alt="Buy Me A Coffee" style="height: 60px !important;width: 217px !important;" > </a>
