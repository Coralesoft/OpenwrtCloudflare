#!/bin/sh /etc/rc.common

# Description:
#   This script automates the installation and setup of Cloudflared on OpenWrt devices.
#
# Table of Contents:
#   1. Pre-checks: System Requirements & Disk Space Validation
#   2. Package Installation
#   3. Cloudflared Download and Installation
#   4. Tunnel Setup:
#      - Locally Managed
#      - Web Console Managed
#   5. Service Configuration
#   6. Cloudflared Updates and Cron Jobs
#
# Cloudflared Installation Script (for Locally and Web Managed)
# install-cloudflared.sh – Script to install Cloudflare Tunnel on a Raspberry Pi or x86 running OpenWrt
# Copyright (C) 2022 – 2025 C. Brown (dev@coralesoft.nz)
# MIT License (see LICENSE in project root)
# Last revised 29/05/2025
# Version: 2025.5.1
# Changelog has been moved to CHANGELOG.md

set -euo pipefail

# ANSI colour functions
print_info()  { printf "\033[0;32m%s\033[0m\n" "$1"; }
print_error() { printf "\033[0;31m%s\033[0m\n" "$1"; }

# Fail with a red error message
die() { print_error "Error: $*"; exit 1; }

# Constants
SPACE_REQ=66560      # Required disk space in KB (~65 MB)
REQUIRED_PKGS="nano wget-ssl jq curl"
INSTALL_TYPE=""

# 1. Pre-checks
check_space() {
  print_info "Checking available disk space..."
  SPACE_AVAIL=$(df / | awk 'NR==2 {print $4}')
  AVAIL_HUMAN=$(df -h / | awk 'NR==2 {print $4}')
  [ "$SPACE_AVAIL" -ge "$SPACE_REQ" ] || die "Insufficient space: $AVAIL_HUMAN available (need ~65 MB)."
  print_info "Disk space OK: $AVAIL_HUMAN"
}

check_machine_type() {
  MACHINE_TYPE=$(uname -m)
  case "$MACHINE_TYPE" in
    aarch64) INSTALL_TYPE=arm64 ;;
    x86_64)  INSTALL_TYPE=amd64 ;;
    *)       die "Unsupported architecture: $MACHINE_TYPE" ;;
  esac
  print_info "Detected machine type: $MACHINE_TYPE → $INSTALL_TYPE"
}

# 2. Package Installation
install_packages() {
  print_info "Updating package lists..."
  opkg update
  for pkg in $REQUIRED_PKGS; do
    if ! opkg list-installed | grep -q "^$pkg "; then
      print_info "Installing missing package: $pkg"
      opkg install "$pkg" || die "Failed to install $pkg"
    fi
  done
  print_info "All required packages are present."
}

# 3. Download & Install cloudflared
install_cloudflared() {
  print_info "Downloading cloudflared for $INSTALL_TYPE..."
  wget -q --show-progress -O /tmp/cloudflared \
    "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-$INSTALL_TYPE"
  chmod 755 /tmp/cloudflared
  mv /tmp/cloudflared /usr/sbin/cloudflared
  print_info "cloudflared installed to /usr/sbin/cloudflared"
}

# 4. Tunnel Setup (interactive)
setup_tunnel() {
  echo
  print_info "Choose your tunnel configuration:"
  print_info "  1) Locally managed"
  print_info "  2) Web console managed"
  read -p "Enter 1 or 2: " INSTOPTION
  case "$INSTOPTION" in
    1) setup_local_tunnel ;;
    2) setup_web_tunnel  ;;
    *) die "Invalid choice" ;;
  esac
}

setup_local_tunnel() {
  print_info "Local tunnel setup..."
  mkdir -p /root/.cloudflared

  cloudflared tunnel login
  read -p "Tunnel name (no spaces): " TUNNAME
  cloudflared tunnel create "$TUNNAME" || die "Tunnel creation failed"
  read -p "Domain (e.g. sub.mydomain.com): " DOMAIN
  cloudflared tunnel route dns "$TUNNAME" "$DOMAIN" || die "DNS routing failed"

  JSON=$(find /root/.cloudflared -iname '*.json' | head -n1)
  UUID=$(basename "$JSON" .json)
  cat <<EOF > /root/.cloudflared/config.yml
tunnel: $UUID
credentials-file: $JSON
ingress:
  - hostname: $DOMAIN
    service: http://localhost:80
  - service: http_status:404
EOF
  print_info "Local tunnel configured at /root/.cloudflared/config.yml"
}

setup_web_tunnel() {
  print_info "Web console–managed tunnel setup..."
  mkdir -p /root/.cloudflared
  print_info "  1. Log into Cloudflare Zero Trust."
  print_info "  2. Create a tunnel and copy its token."
  print_info "  3. Paste the token here."
  read -p "Tunnel token: " TUNNEL_TOKEN
  echo "$TUNNEL_TOKEN" > /root/.cloudflared/tunnel-token
  print_info "Token saved to /root/.cloudflared/tunnel-token"
}

# 5. Service Configuration
configure_service() {
  print_info "Configuring cloudflared as an init.d service..."
  if [ -f /root/.cloudflared/tunnel-token ]; then
    TOKEN=$(cat /root/.cloudflared/tunnel-token)
    CMD="cloudflared tunnel run --token $TOKEN"
  else
    CMD="cloudflared tunnel --config /root/.cloudflared/config.yml run"
  fi

  cat <<EOF > /etc/init.d/cloudflared
#!/bin/sh /etc/rc.common
# Cloudflared tunnel service
# Version: 2025.5.1

USE_PROCD=1
START=38
STOP=50

start_service() {
  sysctl -w net.core.rmem_max=2500000 >/dev/null 2>&1
  procd_open_instance
  procd_set_param command $CMD
  procd_set_param stdout 1
  procd_set_param stderr 1
  procd_set_param respawn 3600 5 5
  procd_close_instance
}
EOF

  chmod 755 /etc/init.d/cloudflared
  /etc/init.d/cloudflared enable
  print_info "Service script enabled"
}

# 6. Updater Script (always installed)
setup_updater() {
  print_info "Installing cloudflared updater script..."
  cat <<'EOF' > /usr/sbin/cloudflared-update
#!/bin/sh
# cloudflared-update – fetch and install latest cloudflared

LATEST=$(curl -s https://api.github.com/repos/cloudflare/cloudflared/releases/latest | jq -r ".tag_name")
OLD=$(cloudflared -v | awk '{print $3}')
if [ "$OLD" = "$LATEST" ]; then
  printf "\033[0;32mcloudflared is up-to-date (%s)\033[0m\n" "$OLD"
else
  printf "\033[0;32mUpdating from %s → %s\033[0m\n" "$OLD" "$LATEST"
  /etc/init.d/cloudflared stop
  wget -q -O /usr/sbin/cloudflared \
    https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-$INSTALL_TYPE
  chmod 755 /usr/sbin/cloudflared
  /etc/init.d/cloudflared start
  printf "\033[0;32mUpdated to %s\033[0m\n" "$LATEST"
fi
EOF
  chmod 755 /usr/sbin/cloudflared-update
  print_info "Updater installed at /usr/sbin/cloudflared-update"
}

# 7. Optional cron job
setup_cron() {
  CRON_JOB="30 12 * * * /usr/sbin/cloudflared-update"
  (crontab -l 2>/dev/null | grep -Fv "$CRON_JOB"; echo "$CRON_JOB") | crontab -
  /etc/init.d/cron reload
  print_info "Cron job added for daily updates at 12:30"
}

# ──────────────────────────────────────────────────────────────────────────────
print_info "=== Starting Cloudflared Installer ==="

check_space
check_machine_type
install_packages
install_cloudflared
setup_tunnel
configure_service
setup_updater

# Ask about auto-updates
echo
read -p "Enable automatic cloudflared updates via cron? [y/N]: " AUTOUPDATE
case "$AUTOUPDATE" in
  [Yy]*) setup_cron ;;
  *)     print_info "Auto-update skipped. To update manually, run '/usr/sbin/cloudflared-update'." ;;
esac

echo
print_info "Starting cloudflared service..."
if ! /etc/init.d/cloudflared start; then
  die "Failed to start service"
fi

print_info "cloudflared is running."
print_info "Installation complete."

exit 0
