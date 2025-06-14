#!/bin/sh
# Cloudflared uninstaller
# Version: 2025.6.1
# (C) 2022 - 2025 C. Brown (dev@coralesoft.nz), MIT License
# Last revised 14/06/2025
#-----------------------------------------------------------------------
# Version      Date         Notes:
# 2025.5.1      29-05-2025   Refine tunnel-deletion logic, remove old creds, rc.d symlinks, reload cron.
# 2025.6.1      14-06-2025   Support /etc/cloudflared layout and /etc/crontabs/root cron removal.
#
echo "#############################################################################"
echo
echo "Starting Cloudflared uninstaller..."
echo

# 1) Stop & disable service
if pgrep cloudflared >/dev/null 2>&1; then
  echo "Stopping Cloudflared service..."
  /etc/init.d/cloudflared stop || true
fi
if [ -f /etc/init.d/cloudflared ]; then
  echo "Disabling Cloudflared service..."
  /etc/init.d/cloudflared disable || true
fi
echo

# 2) Tunnel deletion (local-mode only)
CFG_DIR=/etc/cloudflared
CFG_FILE="$CFG_DIR/config.yml"
TOK_FILE="$CFG_DIR/tunnel-token"

if [ -x /usr/sbin/cloudflared ] && [ -d "$CFG_DIR" ]; then
  if [ -f "$CFG_FILE" ]; then
    echo "Local-mode tunnel detected (config.yml present)."
    /usr/sbin/cloudflared tunnel list || true
    echo
    read -p "Enter the tunnel name to delete (or leave blank to skip): " TUNNAME
    if [ -n "$TUNNAME" ]; then
      echo "Deleting tunnel: $TUNNAME"
      /usr/sbin/cloudflared tunnel delete "$TUNNAME" || true
      echo
    fi

  elif [ -f "$TOK_FILE" ]; then
    echo "Web-managed tunnel detected (token only). Skipping local tunnel deletion."
    echo

  else
    echo "No tunnel credentials found in $CFG_DIR. Skipping tunnel deletion."
    echo
  fi
fi

# 3) Remove configuration directory
if [ -d "$CFG_DIR" ]; then
  echo "Removing Cloudflared configuration directory ($CFG_DIR)..."
  rm -rf "$CFG_DIR"
  echo
fi

# 4) Remove init.d script and any rc.d symlinks
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

# 6) Remove cron job from /etc/crontabs/root
CRON_FILE=/etc/crontabs/root
CRON_JOB="/usr/sbin/cloudflared-update"
if grep -Fq "$CRON_JOB" "$CRON_FILE"; then
  echo "Removing Cloudflared cron job..."
  sed -i "\#${CRON_JOB}#d" "$CRON_FILE"
  echo
fi

# 7) Reload cron
echo "Reloading cron..."
/etc/init.d/cron reload >/dev/null 2>&1

echo
echo "Cloudflared has been completely removed."
echo
echo "#############################################################################"
exit 0
