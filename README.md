# Supports Raspberry Pi 4 and x86 based OpenWrt Routers setting up Cloudflare tunnels


> [!IMPORTANT]
> The official OpenWrt packages feed now has the `cloudflared` package and Luci Application `luci-app-cloudflared` that provides a GUI for configuration.
>  You can install them with the command `opkg install cloudflared luci-app-cloudflared`



This install script will install a Cloudflare tunnel on an Raspberry Pi4 running as a OpenWrt Router\
or running a machine based on OpenWrt x86\
This allows both Locally or Web Managed Tunnels\
Script Version: 2023.5.1

If you like my work :)

<a href="https://www.buymeacoffee.com/r6zt79njh5m" target="_blank"> <img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" alt="Buy Me A Coffee" style="height: 60px !important;width: 217px !important;" > </a>

### Scripts:



## install-cloudflared.sh
This script will completed the full install of Cloudflare tunnel onto a Raspberry Pi or x86 machine running OpenWrt\
The script pulls down the latest version of cloudflared and installs it
- Checks if you want to manage the tunnel Locally or Web via the Cloudflare console 
- Checks there is enough free space
- sets up the service to run it 
- creates the required config in the cloudflare console and  system files
- sets up the service to check for new updates daily and upgrade when avaialable

### Prerequisite:
- You have a active cloudflare account
- You have a domain with DNS managed via cloudflare
- you are logged into the cloudflare web console (time saver)


## uninstall-cloudflared.sh
This Script cleanly uninstalls / removes cloudflared.

