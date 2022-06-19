#!/bin/sh /etc/rc.common
# Cloudflared install
# Script to install cloudflare tunnel on a Raspberry Pi running OpenWrt
# Copyright (C) 2022 C. Brown (dev@coralesoft)
# GNU General Public License
# Last revised 15/06/2022
# version 2202.06.18
#
echo " "
echo "Removing Cloudfared and its condif" 
echo " "
rm /root/.cloudflared/*
rm /etc/init.d/cloudflared
rm /usr/sbin/cloudflared-update
rm /usr/sbin/cloudflared
crontab -l | grep -v '/usr/sbin/cloudflared-update-check.sh' | crontab -
exit 0

