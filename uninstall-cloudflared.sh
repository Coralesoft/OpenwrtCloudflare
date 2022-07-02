#!/bin/sh /etc/rc.common
# Cloudflared install
# Script to install cloudflare tunnel on a Raspberry Pi running OpenWrt
# Copyright (C) 2022 C. Brown (dev@coralesoft)
# GNU General Public License
# Last revised 21/06/2022
# version 2022.07.1
#-----------------------------------------------------------------------
# Version      Date         Notes:
# 1.0                       Inital Release
# 2022.06.2    20.06.2022   Script fixes and updates
# 2022.06.3    21.06.2022   Script cleanup
# 2022.06.8    21.06.2022   Multiple formatting Updates
# 2022.07.1    02.07.2022   Cleanup
#
echo " "
echo "Removing Cloudfared and its config"
echo " "
echo "Stopping the current tunnel"
/etc/init.d/cloudflared stop
cloudflared tunnel list
echo " "
echo " "
read -p "Enter your tunnel name for deletion: " TUNNAME
echo " "
echo "Deleting tunnel: "$TUNNAME
/usr/sbin/cloudflared tunnel delete $TUNNAME
echo " "
echo "Removing config"
rm /root/.cloudflared/*
echo "Removing Service"
rm /etc/init.d/cloudflared
echo "Removing updates"
rm /usr/sbin/cloudflared-update
echo "Removing Deamon"
rm /usr/sbin/cloudflared
echo "Removing crontab entry"
crontab -l | grep -v '/usr/sbin/cloudflared-update' | crontab -
echo " "
echo "Restarting Cron"
/etc/init.d/cron restart
echo " "
echo "Uninstall completed"


exit 0
