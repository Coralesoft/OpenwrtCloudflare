#!/bin/sh /etc/rc.common
# cloudflare-running.sh
# Script to check if cloudflared is running and restart if it has crashed
# Copyright (C) 2022 C. Brown (dev@coralesoft)
# GNU General Public License
# Last revised 15/06/2022
# version 1.0
# 
# run this as a service to check if cloudflare is running
# Setup a cron job to do this as a scheduled task
# example Run every 15 minutes
# */15  * * * * /root/cloudflared-running.sh
# Example run every 10 minutes
# */10  * * * * /root/cloudflared-running.sh
#
echo " "
echo "***************************************************"
echo "**      Checking if cloudflared is running       **"
echo "** github.com/Coralesoft/PiOpenwrtCloudflare     **"
echo "***************************************************"
# commands to update cloudflared tunnel
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
