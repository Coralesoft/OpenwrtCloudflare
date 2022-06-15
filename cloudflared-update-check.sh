#!/bin/sh /etc/rc.common
# Cloudflared daemon update
# run this as a service to regularly update or call as needed
# Setup a cron job to do this as a scheduled task
# example Run at 11:38 am each day
# 38 11 * * * /root/cloudflared-update-check.sh
# Example run at midnight each day
# 0 0 * * * /root/cloudflared-update-check.sh
# note pull checksum and test dont download if same
# C.Brown
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
chmod 755 cloudflared-linux-arm64
VERSION_NEW=$(cloudflared-linux-arm64)
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