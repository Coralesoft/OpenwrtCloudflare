#!/bin/sh /etc/rc.common
# Cloudflared install
# Script to install cloudflare tunnel on a Raspberry Pi running OpenWrt
# Copyright (C) 2022 C. Brown (dev@coralesoft)
# GNU General Public License
# Last revised 1/08/2022
# version 2022.08.1
#-----------------------------------------------------------------------
# Version      Date         Notes:
# 1.0                       Inital Release
# 2022.6.2    20.06.2022   Script fixes and updates
# 2022.6.3    21.06.2022   Script cleanup
# 2022.6.8    21.06.2022   Multiple formatting Updates
# 2022.7.1    02.07.2022   Cleanup
# 2022.8.1    01-08-2022   Make script more robust 
#
echo "#############################################################################"
echo " "
echo "Checking Machine State"
echo " "
CLOUDF_STATE=$(pidof cloudflared >/dev/null && echo "running" || echo "stopped")
echo " "
echo "Removing Cloudfared and its config"
echo " "
if [ "$CLOUDF_STATE" = "running" ]
then
	echo "Stopping the current tunnel"
	/etc/init.d/cloudflared stop
fi

if [ -f "/usr/sbin/cloudflared" ]
then
	cloudflared tunnel list
	echo " "
	echo " "
	read -p "Enter your tunnel name for deletion: " TUNNAME
	echo " "
	echo "Deleting tunnel: "$TUNNAME
	/usr/sbin/cloudflared tunnel delete $TUNNAME
	echo " "
fi
if [ -d "/root/.cloudflared" ] && ! [ -z "$(ls -A /root/.cloudflared)" ]
then
	echo "Removing config"
	rm /root/.cloudflared/*
fi
if [ -f "/etc/init.d/cloudflared" ] 
then 
	echo "Removing Service" 
	rm /etc/init.d/cloudflared 
fi
if [ -f "/usr/sbin/cloudflared-update" ] 
then 
	echo "Removing updater"
	rm /usr/sbin/cloudflared-update
fi
if [ -f "/usr/sbin/cloudflared" ]
then 
	echo "Removing Deamon"
	rm /usr/sbin/cloudflared
fi

if crontab -l | grep -Fq '/usr/sbin/cloudflared-update'
then
	echo "Removing crontab entry"
	crontab -l | grep -v '/usr/sbin/cloudflared-update' | crontab -
	echo " "
	echo "Restarting Cron"
	/etc/init.d/cron restart
	echo " "
fi
echo "Uninstall completed"
echo " "
echo "#############################################################################"
exit 0
