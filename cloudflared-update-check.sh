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
