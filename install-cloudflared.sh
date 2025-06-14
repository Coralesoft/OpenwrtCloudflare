#!/bin/sh
#
# Description:
#   Automates installation and setup of Cloudflared on OpenWrt devices,
#   with full rollback on any failure.
#
# Table of Contents:
#   1. Pre-checks: System Requirements & Disk Space Validation
#   2. Package Installation (includes wget-ssl)
#   3. Cloudflared Download and Installation
#   4. Tunnel Setup (with retry/cancel loop)
#   5. Service Configuration
#   6. Updater Script Installation (uses wget to temp)
#   7. Optional Cron Job for Auto-Updates
#   8. Rollback on Failure
#
# install-cloudflared.sh – Cloudflare Tunnel installer for OpenWrt (arm64/x86_64)
# Copyright (C) 2022–2025 C. Brown (dev@coralesoft.nz)
# MIT License
# Last revised 14/06/2025
# Version: 2025.6.1
# Changelog has been moved to CHANGELOG.md

set -euo pipefail

# ensure root
[ "$(id -u)" -eq 0 ] || {
  echo "Error: this installer must be run as root" >&2
  exit 1
}

# ANSI colour helpers
print_info()   { printf "\033[0;32m%s\033[0m\n" "$1"; }
print_error()  { printf "\033[0;31m%s\033[0m\n" "$1"; }
print_prompt() { printf "\033[0;33m%s\033[0m"   "$1"; }

# Rollback function
rollback() {
  trap - EXIT
  set +e
  print_error "Failure detected – rolling back all changes…"

  [ -f /etc/init.d/cloudflared ] && {
    print_info "Disabling & removing service script"
    /etc/init.d/cloudflared disable >/dev/null 2>&1
    rm -f /etc/init.d/cloudflared
  }

  [ -f /usr/sbin/cloudflared ] && {
    print_info "Removing cloudflared binary"
    rm -f /usr/sbin/cloudflared
  }

  [ -d /etc/cloudflared ] && {
    print_info "Removing configuration directory"
    rm -rf /etc/cloudflared
  }

  [ -f /usr/sbin/cloudflared-update ] && {
    print_info "Removing updater script"
    rm -f /usr/sbin/cloudflared-update
  }

  CRON_JOB="30 12 * * * /usr/sbin/cloudflared-update"
  if grep -Fq "$CRON_JOB" /etc/crontabs/root; then
    print_info "Removing cloudflared-update cron job"
    sed -i "\|${CRON_JOB}|d" /etc/crontabs/root
    /etc/init.d/cron reload >/dev/null 2>&1
  fi

  print_info "Rollback complete."
}

# Die on error
die() {
  print_error "Error: $*"
  exit 1
}

# Trap errors to rollback
trap 'rc=$?; [ "$rc" -ne 0 ] && rollback' EXIT

# Constants
SPACE_REQ=66560            # KB (~65 MB)
REQUIRED_PKGS="nano wget-ssl jq"
INSTALL_TYPE=""

# 1. Pre-checks: disk space
check_space() {
  print_info "Checking available disk space..."
  SPACE_AVAIL=$(df / | awk 'NR==2 {print $4}')
  AVAIL_HUMAN=$(df -h / | awk 'NR==2 {print $4}')
  [ "$SPACE_AVAIL" -ge "$SPACE_REQ" ] || die "Insufficient space: $AVAIL_HUMAN available (need ~65 MB)."
  print_info "Disk space OK: $AVAIL_HUMAN"
}

# 1b. Pre-checks: machine type
check_machine_type() {
  local m=$(uname -m)
  case "$m" in
    aarch64) INSTALL_TYPE=arm64 ;;
    x86_64)  INSTALL_TYPE=amd64 ;;
    *)       die "Unsupported architecture: $m" ;;
  esac
  print_info "Detected $m → $INSTALL_TYPE"
}

# 2. Package installation
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

# 3. Download & install cloudflared
install_cloudflared() {
  print_info "Downloading cloudflared for $INSTALL_TYPE..."
  wget -q --show-progress -O /tmp/cloudflared     "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-$INSTALL_TYPE"     || die "Download failed"
  chmod 755 /tmp/cloudflared
  mv /tmp/cloudflared /usr/sbin/cloudflared
  print_info "Installed to /usr/sbin/cloudflared"
}

# 4. Tunnel setup (local or web-managed)
setup_tunnel() {
  echo
  while true; do
    print_info "Choose your tunnel configuration:"
    print_info "  1) Locally managed"
    print_info "  2) Web console managed"
    print_prompt "Enter 1 or 2 (or 'q' to cancel): "
    read -r INSTOPTION
    case "$INSTOPTION" in
      1) setup_local_tunnel; break ;;
      2) setup_web_tunnel;  break ;;
      [Qq]) die "Installation cancelled by user" ;;
      *) print_error "Invalid choice; please enter 1, 2, or q." ;;
    esac
  done
}

setup_local_tunnel() {
  print_info "Local tunnel setup…"
  cloudflared tunnel login
  print_prompt "Tunnel name (no spaces): "; read -r TUNNAME
  cloudflared tunnel create "$TUNNAME"
  print_prompt "Domain (e.g. sub.domain.com): "; read -r DOMAIN

  mkdir -p /etc/cloudflared
  JSON_SRC=$(find /root/.cloudflared -type f -name '*.json' | head -n1)
  mv "$JSON_SRC" /etc/cloudflared/
  rmdir /root/.cloudflared 2>/dev/null || true

  UUID=$(basename /etc/cloudflared/*.json .json)
  cat <<EOF >/etc/cloudflared/config.yml
tunnel: $UUID
credentials-file: /etc/cloudflared/$UUID.json
ingress:
  - hostname: $DOMAIN
    service: http://localhost:80
  - service: http_status:404
EOF
  cloudflared tunnel route dns "$UUID" "$DOMAIN"
  print_info "Config written to /etc/cloudflared/config.yml"
}

setup_web_tunnel() {
  print_info "Web console-managed tunnel setup…"
  mkdir -p /etc/cloudflared
  print_info "Create a tunnel in Zero Trust and paste its token below."
  print_prompt "Tunnel token: "; read -r TUNNEL_TOKEN
  echo "$TUNNEL_TOKEN" > /etc/cloudflared/tunnel-token
  print_info "Token saved."
}

# 5. Service configuration
configure_service() {
  print_info "Configuring init.d service..."
  if [ -f /etc/cloudflared/tunnel-token ]; then
    CMD="cloudflared tunnel run --token \$(cat /etc/cloudflared/tunnel-token)"
  else
    CMD="cloudflared tunnel --config /etc/cloudflared/config.yml run"
  fi

  cat <<EOF >/etc/init.d/cloudflared
#!/bin/sh /etc/rc.common
# Cloudflared tunnel service
# Version: 2025.6.1

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
  print_info "Service enabled."
}

# 6. Updater script installation
setup_updater() {
  print_info "Installing cloudflared updater script…"
  cat <<'EOF' >/usr/sbin/cloudflared-update
#!/bin/sh
# cloudflared-update – fetch and install latest cloudflared

print_info()  { printf "\033[0;32m%s\033[0m\n" "$1"; }
print_error() { printf "\033[0;31m%s\033[0m\n" "$1"; }

# baked in at install time
INSTALL_TYPE=__INSTALL_TYPE__

TMPFILE="/tmp/cloudflared.$$"

print_info "Checking latest release…"
LATEST=$(wget -qO- https://api.github.com/repos/cloudflare/cloudflared/releases/latest | jq -r ".tag_name")
[ -n "$LATEST" ] || { print_error "Cannot fetch latest version"; exit 1; }

OLD=$(cloudflared -v 2>/dev/null | awk '{print $3}')
print_info "Local version: $OLD, Latest: $LATEST"

[ "$OLD" != "$LATEST" ] || {
  print_info "Already up-to-date ($OLD)"
  exit 0
}

print_info "Stopping cloudflared service…"
/etc/init.d/cloudflared stop
sleep 2

if pgrep cloudflared >/dev/null; then
  print_info "Killing running cloudflared process…"
  killall -q cloudflared
  sleep 1
fi

print_info "Downloading cloudflared $LATEST for $INSTALL_TYPE…"
wget -q --show-progress -O "$TMPFILE"   "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-$INSTALL_TYPE"   || { print_error "Download failed"; rm -f "$TMPFILE"; exit 1; }

print_info "Replacing old binary…"
chmod 755 "$TMPFILE"
mv "$TMPFILE" /usr/sbin/cloudflared

sync
print_info "Restarting service…"
/etc/init.d/cloudflared start

print_info "Updated successfully to $LATEST"
EOF

  sed -i "s|__INSTALL_TYPE__|$INSTALL_TYPE|" /usr/sbin/cloudflared-update
  chmod 755 /usr/sbin/cloudflared-update
  print_info "Updater installed at /usr/sbin/cloudflared-update"
}

# 7. Optional cron job for auto-updates
setup_cron() {
  CRON_JOB="30 12 * * * /usr/sbin/cloudflared-update"
  if ! grep -Fq "$CRON_JOB" /etc/crontabs/root; then
    print_info "Adding daily update cron job (12:30)"
    { printf "%s" "$CRON_JOB"; } >> /etc/crontabs/root
    /etc/init.d/cron reload >/dev/null 2>&1
  else
    print_info "Cron job already present."
  fi
}

# Main installation flow
print_info "=== Starting Cloudflared Installer ==="

check_space
check_machine_type
install_packages
install_cloudflared
setup_tunnel
configure_service
setup_updater

echo
print_prompt "Enable automatic updates via cron? [y/N]: "
read -r AUTOUPDATE
case "$AUTOUPDATE" in
  [Yy]*) setup_cron ;;
  *) print_info "Auto-update skipped. To update manually, run '/usr/sbin/cloudflared-update'." ;;
esac

echo
print_info "Starting service…"
/etc/init.d/cloudflared start

print_info "Installation complete."
trap - EXIT
exit 0
