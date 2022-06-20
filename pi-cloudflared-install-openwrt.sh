#!/bin/sh /etc/rc.common
# Cloudflared install
# Script to install cloudflare tunnel on a Raspberry Pi running OpenWrt
# Copyright (C) 2022 C. Brown (dev@coralesoft)
# GNU General Public License
# Last revised 20/06/2022
# version 2022.06.20
#-----------------------------------------------------------------------
# Version               Notes:
# 1.0                   Inital Release
# 2022.06.20            Script fixes and updates
#
#
echo "***************************************************"
echo "**             Installing cloudflared            **"
echo "**                                               **"
echo "**   github.com/Coralesoft/PiOpenwrtCloudflare   **"
echo "**                                               **"
echo "**            dev@coralesoft.nz                  **"
echo "**                                               **"
echo "***************************************************"
echo " "
#opkg update
#opkg install nano wget-ssl
echo "Downloading Cloudflared "
echo " "
wget --show-progress -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64
echo " "
chmod 755 cloudflared-linux-arm64
echo "Completed download"
echo " "
echo "Installing cloudflared"
cp cloudflared-linux-arm64 /usr/sbin/cloudflared
echo " "
echo "Setting permisions"
chmod 755 /usr/sbin/cloudflared
echo " "
echo "Cloudflared is installed "
echo " "
echo "Time to setup the tunnel"
echo "Open a web browser and log into your cloudflare account in readiness"
echo "You will be prompted to login into your account with a Cloudflare URL "
echo "Copy this URL from the console and paste into your web browser"
echo "Login process will be triggered in 10 seconds"
echo " "
sleep 10
cloudflared tunnel login
echo " "
echo "Create a tunnel once you have logged in"
read -p "Enter your tunnel name: " TUNNAME
cloudflared tunnel create $TUNNAME
echo " "
echo "Populating Tunnel List "
cloudflared tunnel list
sleep 10
echo " "
echo "We are now routing the tunnel to the domain"
read -p "Enter Your Domain name e.g. access.mydomain.com: " DOMAIN
echo " "
cloudflared tunnel route dns $TUNNAME $DOMAIN
echo " "
echo "Generating base config.yml file"
JSON=$(find /root/.cloudflared/ -iname '*json')
UUID=${JSON::-5}
UUID=${UUID:(-36)}
echo " "
echo "Generating config for tunnel: "$UUID

cat << EOF > /root/.cloudflared/config.yml
# an example yml file for the inital config
tunnel: $UUID
credentials-file: $JSON

ingress:
  - hostname: $DOMAIN
    service: http://localhost:8880
  - hostname: opent.domain.nz
    service: http://localhost:80
  - hostname: ssh.domain.nz
    service: ssh://192.168.1.1:22
  - service: http_status:404
EOF

echo "Config file /root/cloudflared/config.yml"
echo "has been generate for tunnel: "$UUID
echo " Update the ingress section as needed"
echo " "
echo "Settting the service"
echo " "
echo " "
cat << EOF > /etc/init.d/cloudflared
#!/bin/sh /etc/rc.common
# Cloudflared tunnel service script
# Script run cloudflared as a service 
# Copyright (C) 2022 C. Brown (dev@coralesoft)
# GNU General Public License
# Last revised 15/06/2022
# version 1.0
# 
#######################################################################
##																
##	IMPORTANT this needs to be copied into the /etc/init.d/  	
##	folder with no file extention (remove the.sh) rename this file 	
##  from cloudflared-service.sh and save as just cloudlfared 
##													
##	https://github.com/Coralesoft/PiOpenwrtCloudflare	
##														
#######################################################################

USE_PROCD=1

START=38
STOP=50
RESTART=55

# fix the cf buffer issues


start_service() {
    sysctl -w net.core.rmem_max=2500000
    procd_open_instance
    procd_set_param command /usr/sbin/cloudflared tunnel --config /root/.cloudflared/config.yml run OpenTun
    procd_set_param stdout 1
    procd_set_param stderr 1
    procd_set_param respawn ${respawn_threshold:-3600} ${respawn_timeout:-5} ${respawn_retry:-5}
    procd_set_param user
    procd_close_instance
}

EOF
echo " "
echo "Setting Permissions"
chmod 755 /etc/init.d/cloudflared
echo " "
/etc/init.d/cloudflared enable
echo " "
echo "installing helper service for Cloudflare updates"
echo " "
cat << "EOF" > /usr/sbin/cloudflared-update
#!/bin/sh /etc/rc.common
# Cloudflared install
# Script to install update cloudflared when a new version is released
# Copyright (C) 2022 C. Brown (dev@coralesoft)
# GNU General Public License
# Last revised 15/06/2022
# version 1.0
#
# Setup a cron job to do this as a scheduled task
# example Run at 11:38 am each day
# 38 11 * * * /root/cloudflared-update-check.sh
# Example run at midnight each day
# 0 0 * * * /root/cloudflared-update-check.sh
# 
#
#
echo "***************************************************"
echo "**      Updating cloudflared check               **"
echo "** github.com/Coralesoft/PiOpenwrtCloudflare     **"
echo "***************************************************"
echo " "
echo " "
echo "Checking new version"
echo " "
wget --show-progress -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64
echo " "
echo "Completed download"
echo " "
echo "Checking version"
VERSION_OLD=$(cloudflared -v)
chmod 755 ./cloudflared-linux-arm64
VERSION_NEW=$(./cloudflared-linux-arm64 -v)
echo "old version: "$VERSION_OLD
echo "new version: "$VERSION_NEW
if [ "$VERSION_OLD" = "$VERSION_NEW" ]
then
	echo " "
	echo "No Change cleaning up"
	echo " "
	rm ./cloudflared-linux-arm64
else
	echo "New version available"
	msgf="Shutting down tunnel "
	PID=$(pidof cloudflared)
	echo $msgf $PID
	/etc/init.d/cloudflared stop
	echo "Replacing cloudflared"
	mv cloudflared-linux-arm64 /usr/sbin/cloudflared
	echo " "
	echo "Replacement is complete"
	echo " "
	echo "Setting permisions"
	chmod 755 /usr/sbin/cloudflared
	echo  " "
	echo "Changing permisions complete"
	echo " "
	echo "Restarting the tunnel"
	/etc/init.d/cloudflared start
	echo " "
	echo "***************************************************"
	echo "Upgrade has been completed"
	echo "***************************************************"
fi
exit 0
EOF
echo " "
chmod 755 /usr/sbin/cloudflared-update
echo " "
sed -i -e '1i30 12 * * * /usr/sbin/cloudflared-update' /etc/crontabs/root
echo " "
rm cloudflared-linux-arm64
echo " "
echo " "
echo "***************************************************"
echo "**             Install is complete               **"
echo "***************************************************"
echo " "
echo "Please configure /root/.cloudflared/config.yml with your site details"
echo " "
echo "Opening config file"
sleep 5
nano /root/.cloudflared/config.yml
echo ""
/etc/init.d/cloudflared start
exit 0
