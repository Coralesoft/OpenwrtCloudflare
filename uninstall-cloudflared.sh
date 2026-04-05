#!/bin/sh
# Cloudflared uninstaller for OpenWrt
# (C) 2022-2026 C. Brown (dev@coralesoft.nz), MIT License
# Version: 2026.4.1
#-----------------------------------------------------------------------

echo "#############################################################################"
echo
echo "Starting Cloudflared uninstaller..."
echo

# stop & disable
if pgrep cloudflared >/dev/null 2>&1; then
  echo "Stopping service..."
  /etc/init.d/cloudflared stop || true
fi
if [ -f /etc/init.d/cloudflared ]; then
  echo "Disabling service..."
  /etc/init.d/cloudflared disable || true
fi
echo

# tunnel cleanup (local-mode only – web-managed ones are deleted from the dashboard)
CFG_DIR=/etc/cloudflared

if command -v cloudflared >/dev/null 2>&1 && [ -d "$CFG_DIR" ]; then
  if [ -f "$CFG_DIR/config.yml" ]; then
    echo "Local-mode tunnel detected."
    cloudflared tunnel list || true
    echo
    read -p "Tunnel name to delete (blank to skip): " TUNNAME
    if [ -n "$TUNNAME" ]; then
      echo "Deleting tunnel: $TUNNAME"
      cloudflared tunnel delete "$TUNNAME" || true
      echo
    fi
  elif [ -f "$CFG_DIR/tunnel-token" ]; then
    echo "Web-managed tunnel – skipping tunnel deletion."
    echo
  fi
fi

# remove config dir
if [ -d "$CFG_DIR" ]; then
  echo "Removing $CFG_DIR..."
  rm -rf "$CFG_DIR"
  echo
fi

# remove init script + symlinks
if [ -f /etc/init.d/cloudflared ]; then
  echo "Removing init.d script..."
  rm -f /etc/init.d/cloudflared
  find /etc/rc.d -name '*cloudflared' -exec rm -f {} \;
  echo
fi

# remove binaries
for bin in /usr/sbin/cloudflared /usr/sbin/cloudflared-update; do
  if [ -f "$bin" ]; then
    echo "Removing $(basename "$bin")..."
    rm -f "$bin"
  fi
done
echo

# remove cron job
CRON_FILE=/etc/crontabs/root
if [ -f "$CRON_FILE" ] && grep -Fq "/usr/sbin/cloudflared-update" "$CRON_FILE"; then
  echo "Removing cron job..."
  sed -i "\#/usr/sbin/cloudflared-update#d" "$CRON_FILE"
fi
/etc/init.d/cron reload >/dev/null 2>&1

# if someone installed the OpenWrt package too, clean that up
if command -v apk >/dev/null 2>&1; then
  apk info -e cloudflared >/dev/null 2>&1 && {
    echo "Removing cloudflared package..."
    apk del cloudflared || true
  }
elif command -v opkg >/dev/null 2>&1; then
  opkg list-installed 2>/dev/null | grep -q "^cloudflared " && {
    echo "Removing cloudflared package..."
    opkg remove cloudflared || true
  }
fi
rm -f /etc/config/cloudflared

echo
echo "Cloudflared removed."
echo
echo "#############################################################################"
exit 0
