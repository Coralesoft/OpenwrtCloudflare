#!/bin/sh /etc/rc.common
# Cloudflared install
# Script to install cloudflare tunnel on a Raspberry Pi running OpenWrt
# Copyright (C) 2022 C. Brown (dev@coralesoft)
# GNU General Public License
# Last revised 20/06/2022
# version 2202.06.2
#
echo " "
echo "Removing Cloudfared and its config"
echo " "
echo "Stopping the current tunnel"
/etc/init.d/cloudflared stop
cloudflared tunnel list
read -p "Enter your tunnel name for deletion: " TUNNAME
echo " "
echo "Deleting tunnel: "$TUNNAME
/usr/sbin/cloudflared tunnel delete $TUNNAME
echo " "
echo"Removing config"
rm /root/.cloudflared/*
echo "Removing Service"
rm /etc/init.d/cloudflared
echo "Removing updates"
rm /usr/sbin/cloudflared-update
echo "Removing Deamon"
rm /usr/sbin/cloudflared
echo "Remving crontab"
crontab -l | grep -v '/usr/sbin/cloudflared-update' | crontab -
echo " "
/etc/init.d/cron restart
echo "Uninstall completed"

exit 0
