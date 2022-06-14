#!/bin/sh /etc/rc.common
# Cloudflared is running check
# run this as a service to check if cloudflare is update
# Setup a cron job to do this as a scheduled task
# example Run at 11:38 am each day
# 38 11 * * * /usr/sbin/cloudflared-update.sh
# Example run at midnight each day
# 0 0 * * * /usr/sbin/cloudflared-update.sh
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
        echo "Cloudflare is Up pid: "$PID
        echo " "
fi

exit 0
