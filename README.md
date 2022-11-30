# Supports Raspberry Pi 4 and x86 based OpenWrt Routers setting up Cloudflare tunnels

This install script will install a Cloudflare tunnel on an Rasberry Pi4 running as a OpenWrt Router\
or running a machine based on OpenWrt x86\
This allows both Locally or Web Managed Tunnels\
Script Version: 2022.11.1

[if you like this work please buy me a coffee :)](https://www.buymeacoffee.com/r6zt79njh5m)

<script type="text/javascript" src="https://cdnjs.buymeacoffee.com/1.0.0/button.prod.min.js" data-name="bmc-button" data-slug="r6zt79njh5m" data-color="#FFDD00" data-emoji=""  data-font="Cookie" data-text="Buy me a coffee" data-outline-color="#000000" data-font-color="#000000" data-coffee-color="#ffffff" ></script>

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


## Todo

* [ ] Openwrt LuCI App


