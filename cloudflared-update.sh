#!/bin/sh /etc/rc.common
# Cloudflared daemon update
# run this as a service to regularly update or call as needed
# Setup a cron job to do this as a scheduled task
# example Run at 11:38 am each day
# 38 11 * * * /usr/sbin/cloudflared-update.sh
# Example run at midnight each day
# 0 0 * * * /usr/sbin/cloudflared-update.sh
#
echo "***************************************************"
echo "**             updating cloudflared              **"
echo "** github.com/Coralesoft/PiOpenwrtCloudflare     **"
echo "***************************************************"
# commands to update cloidflared tunnel
echo " "
msgf="Killing current tunnel pid "
PID=$(pidof cloudflared)
echo $msgf $PID

killall -9 cloudflared

echo " "
echo "Downloading new version"
echo " "
wget --show-progress -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64
echo " "
echo "Completed download"
echo " "
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
echo " "
/etc/init.d/cloudflared start
echo " "
echo "Upgrade has been completed"
echo "***************************************************"

exit 0
