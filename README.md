# PiOpenwrtCloudflare
This is a colection of scripts and instructions to on how to setup a cloudflare tunnel on an Rasberry Pi4 running as a OpenWrt router

Scripts:
cloudflare-service.sh
  This script is used to run cloudflared as a service on OpenWrt
  IMPORTANT this needs to be copied into the /etc/init.d/ folder with no file extention (remove the.sh) 
  rename this file from cloudflared-service.sh and save as just cloudlfared and will look like
  /etc/init.d/cloudflared
  
  This service will now appear in the startup screen

cloudflare-update.sh
  This script will download the latest copy of cloudflared from thier github and replace the exisitng binary
  this can alos be used for the inital download and setup of the binary
