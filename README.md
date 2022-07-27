# Supports Raspberry Pi 4 and OpenWrt_x86 based 
# OpenWrt Routers running Cloudflare tunnels

This install script will install a Cloudflare tunnel on an Rasberry Pi4 running as a OpenWrt Router\
or running a machine based on OpenWrt x86\
Script Version: 2022.07.2

### Scripts:



## install-cloudflared.sh
This script will completed the full install of Cloudflare tunnel onto a Raspberry Pi or x86 machine running OpenWrt
The script pulls down the latest version of cloudflared and installs it
- Checks there is enough free space
- sets up the service to run it 
- creates the required config in the cloudflare console and  system files
- sets up the service to check for new updates daily

### Prerequisite:
- You have a active cloudflare account
- You have a domain with DNS managed via cloudflare
- you are logged into the cloudflare web console (time saver)


## uninstall-cloudflared.sh
This Script cleanly uninstalls / removes cloudflared.




