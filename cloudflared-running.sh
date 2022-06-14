#!/bin/sh /etc/rc.common
# Cloudflared is running check
# run this as a service to check if cloudflare is running
# Setup a cron job to do this as a scheduled task
# example Run every 15 minutes
# */15  * * * * /usr/sbin/cloudflared-running.sh
# Example run every 10 minutes
# */10  * * * * /usr/sbin/cloudflared-running.sh
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

