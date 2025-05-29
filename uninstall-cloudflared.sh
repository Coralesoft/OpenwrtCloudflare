#!/bin/sh /etc/rc.common
# Cloudflared uninstall
# Version: 2025.5.1
# (C) 2022 - 2025 C. Brown (dev@coralesoft.nz), MIT License
# Last revised 29/05/2025
#-----------------------------------------------------------------------
# Version      Date         Notes:
# 1.0                       Inital Release
# 2022.6.2    20.06.2022   Script fixes and updates
# 2022.6.3    21.06.2022   Script cleanup
# 2022.6.8    21.06.2022   Multiple formatting Updates
# 2022.7.1    02.07.2022   Cleanup
# 2022.8.1    01-08-2022   Make script more robust 
# 2022.9.2    11-09-2022   Added support for Web Managed config 
# 2023.5.1    08-05-2023   Cleanup scripts
# 2024.3.1    08-03-2024   New Release
# 2025.5.1    29-05-2025   Refine tunnel-deletion logic: detect local-mode via config.yml, 	
#			   skip listing when no credentials, stop & disable service properly, 	
#			   remove full ~/.cloudflared folder and rc.d symlinks, and reload cron.
#
echo "#############################################################################"
echo
echo "Starting Cloudflared uninstaller..."
echo

# 1) Stop & disable service
if pidof cloudflared >/dev/null; then
  echo "Stopping Cloudflared service..."
  /etc/init.d/cloudflared stop || true
fi
if [ -f /etc/init.d/cloudflared ]; then
  echo "Disabling Cloudflared service..."
  /etc/init.d/cloudflared disable || true
fi
echo

# 2) Tunnel deletion (local-mode only)
CFG=/root/.cloudflared/config.yml
TOK=/root/.cloudflared/tunnel-token

if [ -x /usr/sbin/cloudflared ] && [ -d /root/.cloudflared ]; then
  if [ -f "$CFG" ]; then
    echo "Local-mode tunnel detected (config.yml present)."
    /usr/sbin/cloudflared tunnel list
    echo
    read -p "Enter the tunnel name to delete (or leave blank to skip): " TUNNAME
    if [ -n "$TUNNAME" ]; then
      echo "Deleting tunnel: $TUNNAME"
      /usr/sbin/cloudflared tunnel delete "$TUNNAME" || true
      echo
    fi

  elif [ -f "$TOK" ]; then
    echo "Web-managed tunnel detected (token only). Skipping local tunnel deletion."
    echo

  else
    echo "No tunnel credentials found in /root/.cloudflared. Skipping tunnel deletion."
    echo
  fi
fi

# 3) Remove all config
if [ -d /root/.cloudflared ]; then
  echo "Removing Cloudflared configuration directory..."
  rm -rf /root/.cloudflared
  echo
fi

# 4) Remove init.d and any leftover rc.d symlinks
if [ -f /etc/init.d/cloudflared ]; then
  echo "Removing init.d script..."
  rm -f /etc/init.d/cloudflared
  find /etc/rc.d -name '*cloudflared' -exec rm -f {} \;
  echo
fi

# 5) Remove binaries
for bin in /usr/sbin/cloudflared /usr/sbin/cloudflared-update; do
  if [ -f "$bin" ]; then
    echo "Removing $(basename "$bin")..."
    rm -f "$bin"
  fi
done
echo

# 6) Remove cron job
CRON_JOB="/usr/sbin/cloudflared-update"
if crontab -l 2>/dev/null | grep -qF "$CRON_JOB"; then
  echo "Removing Cloudflared cron job..."
  (crontab -l 2>/dev/null | grep -vF "$CRON_JOB") | crontab -
  echo
fi

# 7) Reload cron
echo "Reloading cron..."
/etc/init.d/cron reload

echo
echo "Cloudflared has been completely removed."
echo
echo "#############################################################################"
exit 0
