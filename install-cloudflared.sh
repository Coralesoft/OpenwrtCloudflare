#!/bin/sh
# install-cloudflared.sh – Cloudflare Tunnel installer for OpenWrt
# Downloads cloudflared from GitHub and walks you through setting up
# a tunnel (local or web-managed).
# (C) 2022-2026 C. Brown (dev@coralesoft.nz), MIT License
# Version: 2026.4.1
#-----------------------------------------------------------------------

set -euo pipefail

[ "$(id -u)" -eq 0 ] || { echo "Error: must be run as root" >&2; exit 1; }

# colours
print_info()   { printf "\033[0;32m%s\033[0m\n" "$1"; }
print_error()  { printf "\033[0;31m%s\033[0m\n" "$1"; }
print_prompt() { printf "\033[0;33m%s\033[0m"   "$1"; }

# work out which package manager we're dealing with
if command -v apk >/dev/null 2>&1; then
  PKG_MGR=apk
elif command -v opkg >/dev/null 2>&1; then
  PKG_MGR=opkg
else
  echo "Error: no supported package manager (need apk or opkg)" >&2
  exit 1
fi

INSTALL_TYPE=""

rollback() {
  trap - EXIT
  set +e
  print_error "Something went wrong – rolling back…"

  [ -f /etc/init.d/cloudflared ] && {
    /etc/init.d/cloudflared disable >/dev/null 2>&1
    rm -f /etc/init.d/cloudflared
  }
  rm -f /usr/sbin/cloudflared
  rm -f /usr/sbin/cloudflared-update
  rm -rf /etc/cloudflared

  CRON_JOB="30 12 * * * /usr/sbin/cloudflared-update"
  if [ -f /etc/crontabs/root ] && grep -Fq "$CRON_JOB" /etc/crontabs/root; then
    sed -i "\|${CRON_JOB}|d" /etc/crontabs/root
    /etc/init.d/cron reload >/dev/null 2>&1
  fi

  print_info "Rollback done."
}

die() {
  print_error "Error: $*"
  exit 1
}

trap 'rc=$?; [ "$rc" -ne 0 ] && rollback' EXIT

SPACE_REQ=66560  # ~65 MB

#-----------------------------------------------------------------------

check_existing() {
  # if there's already a tunnel configured, ask before blowing it away
  if [ -d /etc/cloudflared ] && { [ -f /etc/cloudflared/config.yml ] || [ -f /etc/cloudflared/tunnel-token ]; }; then
    print_error "Existing tunnel config found in /etc/cloudflared/"
    print_prompt "Overwrite and reconfigure? [y/N]: "
    read -r answer
    case "$answer" in
      [Yy]*)
        pgrep cloudflared >/dev/null 2>&1 && {
          print_info "Stopping running service..."
          /etc/init.d/cloudflared stop 2>/dev/null || true
        }
        rm -rf /etc/cloudflared
        rm -f /usr/sbin/cloudflared /usr/sbin/cloudflared-update
        ;;
      *)
        print_info "Leaving existing config alone."
        trap - EXIT
        exit 0
        ;;
    esac
  fi

  # clean up the OpenWrt package version if someone installed that
  if [ "$PKG_MGR" = "apk" ]; then
    apk info -e cloudflared >/dev/null 2>&1 && {
      print_info "Removing cloudflared package (we use our own binary)."
      apk del cloudflared >/dev/null 2>&1 || true
    }
  else
    opkg list-installed 2>/dev/null | grep -q "^cloudflared " && {
      print_info "Removing cloudflared package (we use our own binary)."
      opkg remove cloudflared >/dev/null 2>&1 || true
    }
  fi
  rm -f /etc/config/cloudflared
}

check_space() {
  print_info "Checking disk space..."
  avail=$(df / | awk 'NR==2 {print $4}')
  human=$(df -h / | awk 'NR==2 {print $4}')
  [ "$avail" -ge "$SPACE_REQ" ] || die "Not enough space: $human free (need ~65 MB)"
  print_info "Disk space OK ($human free)"
}

check_arch() {
  m=$(uname -m)
  case "$m" in
    aarch64) INSTALL_TYPE=arm64 ;;
    x86_64)  INSTALL_TYPE=amd64 ;;
    *)       die "Unsupported architecture: $m" ;;
  esac
  print_info "Architecture: $m ($INSTALL_TYPE)"
}

install_packages() {
  print_info "Installing dependencies via $PKG_MGR..."
  if [ "$PKG_MGR" = "apk" ]; then
    apk update
    for pkg in nano wget-ssl jq; do
      apk info -e "$pkg" >/dev/null 2>&1 || apk add "$pkg" || die "Failed to install $pkg"
    done
  else
    opkg update
    for pkg in nano wget-ssl jq; do
      opkg list-installed | grep -q "^$pkg " || opkg install "$pkg" || die "Failed to install $pkg"
    done
  fi
  print_info "Done."
}

install_cloudflared() {
  print_info "Downloading cloudflared for $INSTALL_TYPE..."
  wget -q --show-progress -O /tmp/cloudflared \
    "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-$INSTALL_TYPE" \
    || die "Download failed"
  chmod 755 /tmp/cloudflared
  mv /tmp/cloudflared /usr/sbin/cloudflared
  print_info "Installed to /usr/sbin/cloudflared"
}

setup_tunnel() {
  echo
  while true; do
    print_info "Tunnel type:"
    print_info "  1) Locally managed"
    print_info "  2) Web console managed"
    print_prompt "Pick 1 or 2 (q to cancel): "
    read -r choice
    case "$choice" in
      1) setup_local_tunnel; break ;;
      2) setup_web_tunnel;  break ;;
      [Qq]) die "Cancelled." ;;
      *) print_error "Invalid choice." ;;
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
  json=$(find /root/.cloudflared -type f -name '*.json' | head -n1)
  mv "$json" /etc/cloudflared/
  rmdir /root/.cloudflared 2>/dev/null || true

  uuid=$(basename /etc/cloudflared/*.json .json)
  cat <<EOF >/etc/cloudflared/config.yml
tunnel: $uuid
credentials-file: /etc/cloudflared/$uuid.json
ingress:
  - hostname: $DOMAIN
    service: http://localhost:80
  - service: http_status:404
EOF
  cloudflared tunnel route dns "$uuid" "$DOMAIN"
  print_info "Config written to /etc/cloudflared/config.yml"
}

setup_web_tunnel() {
  print_info "Web-managed tunnel setup…"
  mkdir -p /etc/cloudflared
  print_info "Create a tunnel in Zero Trust and paste the token below."
  print_prompt "Tunnel token: "; read -r token
  echo "$token" > /etc/cloudflared/tunnel-token
  print_info "Token saved."
}

configure_service() {
  print_info "Writing init.d service..."

  if [ -f /etc/cloudflared/tunnel-token ]; then
    cmd="/usr/sbin/cloudflared tunnel --no-autoupdate run --token \$(cat /etc/cloudflared/tunnel-token)"
  else
    cmd="/usr/sbin/cloudflared tunnel --no-autoupdate --config /etc/cloudflared/config.yml run"
  fi

  cat <<EOF >/etc/init.d/cloudflared
#!/bin/sh /etc/rc.common
USE_PROCD=1
START=99
STOP=50

start_service() {
  sysctl -w net.core.rmem_max=2500000 >/dev/null 2>&1
  procd_open_instance
  procd_set_param command $cmd
  procd_set_param stdout 1
  procd_set_param stderr 1
  procd_set_param respawn 3600 5 5
  procd_close_instance
}

service_triggers() {
  procd_add_interface_trigger "interface.*.up" "wan" /etc/init.d/cloudflared restart
}
EOF

  chmod 755 /etc/init.d/cloudflared
  /etc/init.d/cloudflared enable
  print_info "Service enabled."
}

setup_updater() {
  print_info "Installing updater script..."
  cat <<'EOF' >/usr/sbin/cloudflared-update
#!/bin/sh
# cloudflared-update – grab the latest cloudflared from GitHub

print_info()  { printf "\033[0;32m%s\033[0m\n" "$1"; }
print_error() { printf "\033[0;31m%s\033[0m\n" "$1"; }

INSTALL_TYPE=__INSTALL_TYPE__
TMPFILE="/tmp/cloudflared.$$"

print_info "Checking latest release…"
LATEST=$(wget -qO- https://api.github.com/repos/cloudflare/cloudflared/releases/latest | jq -r ".tag_name")
[ -n "$LATEST" ] || { print_error "Couldn't fetch latest version"; exit 1; }

OLD=$(cloudflared -v 2>/dev/null | awk '{print $3}')
print_info "Installed: $OLD  Latest: $LATEST"

[ "$OLD" != "$LATEST" ] || { print_info "Already up to date."; exit 0; }

print_info "Stopping service…"
/etc/init.d/cloudflared stop
sleep 2

pgrep cloudflared >/dev/null && { killall -q cloudflared; sleep 1; }

print_info "Downloading cloudflared $LATEST…"
wget -q --show-progress -O "$TMPFILE" \
  "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-$INSTALL_TYPE" \
  || { print_error "Download failed"; rm -f "$TMPFILE"; exit 1; }

chmod 755 "$TMPFILE"
mv "$TMPFILE" /usr/sbin/cloudflared
sync

print_info "Restarting service…"
/etc/init.d/cloudflared start
print_info "Updated to $LATEST"
EOF

  sed -i "s|__INSTALL_TYPE__|$INSTALL_TYPE|" /usr/sbin/cloudflared-update
  chmod 755 /usr/sbin/cloudflared-update
  print_info "Updater at /usr/sbin/cloudflared-update"
}

setup_cron() {
  CRON_JOB="30 12 * * * /usr/sbin/cloudflared-update"
  if ! grep -Fq "$CRON_JOB" /etc/crontabs/root 2>/dev/null; then
    print_info "Adding daily update cron job (12:30)"
    printf "%s\n" "$CRON_JOB" >> /etc/crontabs/root
    /etc/init.d/cron reload >/dev/null 2>&1
  else
    print_info "Cron job already there."
  fi
}

#-----------------------------------------------------------------------
# main
#-----------------------------------------------------------------------

print_info "=== Cloudflared Installer ==="
print_info "Using $PKG_MGR"

check_existing
check_space
check_arch
install_packages
install_cloudflared
setup_tunnel
configure_service
setup_updater

echo
print_prompt "Enable daily auto-update via cron? [y/N]: "
read -r AUTOUPDATE
case "$AUTOUPDATE" in
  [Yy]*) setup_cron ;;
  *) print_info "Skipped. Run '/usr/sbin/cloudflared-update' to update manually." ;;
esac

echo
print_info "Starting service…"
/etc/init.d/cloudflared start

print_info "All done."
trap - EXIT
exit 0
