# Raspberry Pi 4 OpenWrt Router running Cloudflare tunnels

This is an install script to setup a Cloudflare tunnel on an Rasberry Pi4 running as a OpenWrt router

### Scripts:



## install-cloudflared.sh
This script will completed the full install of Cloudflare tunnel onto a Raspberry Pi running OpenWrt
The script pulls down the latest version of cloudflared and installs it 
- sets up the service to run it 
- creates the required config in the cloudflare console and  system files
- sets up the service to check for new updates daily

### Prerequisite:
- You have a active cloudflare account
- You have a domain with DNS managed via cloudflare
- you are logged into the cloudflare web console (time saver)


## uninstall-cloudflared.sh
This Script cleanly uninstalls / removes cloudflared.


