#!/bin/sh /etc/rc.common
# Cloudflared install
# Script to update the Cloudflare binary
# Copyright (C) 2022 C. Brown (dev@coralesoft)
# GNU General Public License
# Last revised 15/06/2022
# version 1.0
#
# run this as a service to regularly update or call as needed
# Setup a cron job to do this as a scheduled task
# example Run at 11:38 am each day
# 38 11 * * * /root/cloudflared-update.sh
# Example run at midnight each day
# 0 0 * * * /root/cloudflared-update.sh
# note pull checksum and test dont download if same
#
echo "***************************************************"
echo "**             updating cloudflared              **"
echo "** github.com/Coralesoft/PiOpenwrtCloudflare     **"
echo "***************************************************"
# commands to update cloudflared tunnel
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

/etc/init.d/cloudflared start

echo "Upgrade has been completed"
echo "***************************************************"

exit 0
