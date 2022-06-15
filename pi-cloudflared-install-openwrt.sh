#!/bin/sh /etc/rc.common
# Cloudflared install
# Script by C. Brown 2022
echo "***************************************************"
echo "**             Installing cloudflared            **"
echo "**                                               **"
echo "** github.com/Coralesoft/PiOpenwrtCloudflare     **"
echo "** C. Brown   dev@coralesoft.nz                  **"
echo "***************************************************"
echo " "
opkg update
opkg install nano wget-ssl
echo "Downloading Cloudflared "
echo " "
wget --show-progress -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64
echo " "
echo "Completed download"
echo " "
echo "Installing cloudflared"
mv cloudflared-linux-arm64 /usr/sbin/cloudflared
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
read -p "Enter your tunnel name" TUNNAME
cloudflared tunnel create $TUNNAME
echo " "
echo "Populating Tunnel List "
cloudflared tunnel list
echo " "
echo "We are now routing the tunnel to the domain"
read -p "Enter Your Domain name e.g. access.mydomain.com" DOMAIN
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
  - hostname: opent.mydomain.nz
    service: http://localhost:80
  - hostname: netdata.mydomain.nz
    service: http://localhost:8880
  - hostname: ssh.mydomain.nz
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
# Script by C.Brown dev@coralesoft.nz
#######################################################################
##								
##	IMPORTANT this needs to be copied into the /etc/init.d/  	
##	folder with no file extention (remove the.sh) rename this file 
##  from cloudflared-service.sh and save as just cloudlfared 
##								
##	https://github.com/Coralesoft/PiOpenwrtCloudflare
##					
#######################################################################

START=38
STOP=50
RESTART=55

# fix the cf buffer issues
sysctl -w net.core.rmem_max=2500000

#start commands
start() {
        echo starting
        # Start the cloudflare service commands to launch cloidflared tunnel
		# Supplying the config directory and tunnel name plus log file.
		# Update the config and tunnel name to suit your setup
		#/usr/bin/cloudflared tunnel --config <<CONFIG LOCATION>> run <<TUNNELNAME>> &> /root/.cloudflared/<<LOGFILE>> &
        
		/usr/bin/cloudflared tunnel --config /root/.cloudflared/config.yml run $TUNNAME &> /root/.cloudflared/tunnellogs.txt &
        
		# execute the tunnel and log to the tunnellogs file
}

stop() {
        echo stopping
        # Kill the running tunnel
        killall -9 cloudflared
}
restart() {
		# restart for the service
        echo restarting
        killall -9 cloudflared
		# give it time to clean up
        sleep 2
		# Start the service
        /usr/bin/cloudflared tunnel --config /root/.cloudflared/config.yml run $TUNNAME &> /root/.cloudflared/tunnellogs.txt &
}

# end of script


// finish the service file 
exit 0

EOF
echo " "
echo "Setting Permissions"
chmod 755 /etc/init.d/cloudflared
echo " "
echo "Please enable when your ready in the Luci startup page"
echo " "
echo "installing helper service for Cloudflare updates"
echo " "

cat << EOF > /usr/sbin/cloudflared-update
#!/bin/sh /etc/rc.common
# Cloudflared daemon update
# run this as a service to regularly update or call as needed
# Setup a cron job to do this as a scheduled task
# example Run at 11:38 am each day
# 38 11 * * * /root/cloudflared-update-check.sh
# Example run at midnight each day
# 0 0 * * * /root/cloudflared-update-check.sh
# 
# Script by C.Brown dev@coralesoft.nz
#
echo "***************************************************"
echo "**      Updating cloudflared check               **"
echo "** github.com/Coralesoft/PiOpenwrtCloudflare     **"
echo "***************************************************"
# commands to update cloudflared tunnel
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
	msgf="Killing current tunnel pid "
	PID=$(pidof cloudflared)
	echo $msgf $PID
	killall -9 cloudflared
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
cat << EOF >> /etc/crontabs/root
0 0 * * * /usr/sbin/cloudflared-update
EOF
echo " "
echo "installing helper service for ensuring tunnel is running"
echo " "
cat << EOF > /usr/sbin/cloudflared-running
#!/bin/sh /etc/rc.common
# Cloudflared is running check
# run this as a service to check if cloudflare is running
# Setup a cron job to do this as a scheduled task
# example Run every 15 minutes
# */15  * * * * /root/cloudflared-running.sh
# Example run every 10 minutes
# */10  * * * * /root/cloudflared-running.sh
# Script by C.Brown dev@coralesoft.nz
#
echo " "
echo "***************************************************"
echo "**      Checking if cloudflared is running       **"
echo "** github.com/Coralesoft/PiOpenwrtCloudflare     **"
echo "***************************************************"
# commands to update cloidflared tunnel
echo " "
PID=$(pidof cloudflared)
if [ -z "$PID" ]
then
      echo "Cloudflare is down"
	  echo "Restarting Cloudflare"
	  echo " "
	  /etc/init.d/cloudflared start
	  echo " "

else
      echo "Cloudflare is Up"
	  echo " "
fi

exit 0

EOF

echo " "
chmod 755 /usr/sbin/cloudflared-running
echo " "
cat << EOF >> /etc/crontabs/root
*/15  * * * * /usr/sbin/cloudflared-running
EOF
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

exit 0
