# Raspberry Pi 4 OpenWrt Router running Cloudflare tunnels

This is a colection of scripts and instructions to on how to setup a cloudflare tunnel on an Rasberry Pi4 running as a OpenWrt router

### Scripts:



## pi-cloudflared-install-openwrt.sh
This script will completed the full install of Cloudflare tunnel onto a Raspberry Pi running OpenWrt
The script pulls down the latest version of cloudflared and installs it 
- sets up the service to run it 
- creates the required config in the cloudflare console and  system files
- sets up the service to check for new updates daily 
- creats a service to monitor the tunnel is up and running



### Prerequisite:
- You have a active cloudflare account
- You have a domain with DNS managed via cloudflare
- you are logged into the cloudflare web console 

## cloudflare-service.sh

  This script is used to run cloudflared as a service on OpenWrt \
  IMPORTANT this needs to be copied into the /etc/init.d/ folder with no file extention (remove the.sh)\
  rename this file from cloudflared-service.sh and save as just cloudlfared and will look like \
  /etc/init.d/cloudflared
  
  This service will now appear in the startup screen

## cloudflared-update-check.sh

  This script will check if there is a newer version of cloudflaread and if there is\ 
  a newer version download the latest copy of cloudflared from thier github and replace the exisitng binary\
  
  Setup a cron job to do this as a scheduled task (examples below)
  
  Example Run at 11:38 am each day\
  38 11 * * * /usr/sbin/cloudflared-update.sh\
  Example run at midnight each day\
  0 0 * * * /usr/sbin/cloudflared-update.sh

## cloudflare-update.sh

  This script will download the latest copy of cloudflared from thier github and replace the exisitng binary\
  this can also be used for the inital download and setup of the binary\
  Setup a cron job to do this as a scheduled task
  
  Example Run at 11:38 am each day\
  38 11 * * * /usr/sbin/cloudflared-update.sh\
  Example run at midnight each day\
  0 0 * * * /usr/sbin/cloudflared-update.sh
  
## cloudflared-running.sh

This script is used to check if the cloudflared service is running and will restart the service if its down\
Setup a cron job to do this as a scheduled task\
example Run every 15 minutes\
*/15  * * * * /usr/sbin/cloudflared-running.sh\
Example run every 10 minutes\
*/10  * * * * /usr/sbin/cloudflared-running.sh

## Install and setup
Read Cloudflare on OpenWrt(Draft work in progress).txt for manual instructions to go through the whole process

