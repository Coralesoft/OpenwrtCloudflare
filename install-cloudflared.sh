#!/bin/sh
# install-cloudflared.sh – Cloudflare Tunnel installer for OpenWrt
# Downloads cloudflared from GitHub and walks you through setting up
# a tunnel (local or web-managed).
# (C) 2022-2026 C. Brown (dev@coralesoft.nz), MIT License
# Version: 2026.10.0
#-----------------------------------------------------------------------

set -euo pipefail

[ "$(id -u)" -eq 0 ] || { echo "Error: must be run as root" >&2; exit 1; }

# colours
print_info()   { printf "\033[0;32m%s\033[0m\n" "$1"; }
print_error()  { printf "\033[0;31m%s\033[0m\n" "$1"; }
print_prompt() { printf "\033[0;33m%s\033[0m"   "$1"; }

# download $1 to file $2 with whatever fetcher works (wget, then curl).
# Both give up on a stalled connection rather than hanging forever.
fetch() {
  if command -v wget >/dev/null 2>&1 && wget -T 60 -O "$2" "$1"; then
    return 0
  fi
  if command -v curl >/dev/null 2>&1 && curl -fL --connect-timeout 30 --speed-limit 1024 --speed-time 60 -o "$2" "$1"; then
    return 0
  fi
  return 1
}

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
UPGRADE_ONLY=0    # set when re-running over an existing install
FRESH_INSTALL=0   # set once we're past the existing-install prompt and
                  # it's safe to delete everything on failure
BACKUP_DIR=""
WORKDIR=""
EXISTING_ACTION=none   # set by the prompt, carried out after the lock
LOCK=/var/lock/cloudflared-update.lock   # shared with the updater (flock)

rollback() {
  trap - EXIT
  set +e
  stty echo 2>/dev/null
  [ -n "$WORKDIR" ] && rm -rf "$WORKDIR"
  rm -f /usr/sbin/cloudflared.new

  # upgrading in place: the tunnel config and binary were already there
  # and must stay. Put the old service and updater scripts back instead.
  if [ "$UPGRADE_ONLY" -eq 1 ]; then
    print_error "Something went wrong – rolling back…"
    if [ -n "$BACKUP_DIR" ] && [ -d "$BACKUP_DIR" ]; then
      [ -f "$BACKUP_DIR/cloudflared" ] && cp -a "$BACKUP_DIR/cloudflared" /etc/init.d/cloudflared
      [ -f "$BACKUP_DIR/cloudflared-update" ] && cp -a "$BACKUP_DIR/cloudflared-update" /usr/sbin/cloudflared-update
      print_info "Restored previous service and updater scripts from $BACKUP_DIR"
    fi
    /etc/init.d/cloudflared restart >/dev/null 2>&1
    print_info "Rollback done. Tunnel config and binary were left alone."
    return
  fi

  # not past the prompt yet (EOF on stdin, Ctrl-C, a failed package
  # command): nothing of ours has been written, and an existing install
  # must not be touched
  if [ "$FRESH_INSTALL" -ne 1 ]; then
    print_error "Stopped before anything was changed."
    return
  fi

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

# shared with the updater. require flock so a cron or restore-hook update
# can't change the binary or scripts underneath us; keep the lock file,
# closing the descriptor releases the lock. runs before the rollback trap
# is armed, so a failure here just exits.
take_lock() {
  command -v flock >/dev/null 2>&1 || die "flock is required but missing; nothing has been changed"
  mkdir -p "$(dirname "$LOCK")" || die "Couldn't create the lock directory $(dirname "$LOCK")"
  exec 9>"$LOCK"
  flock -n 9 || die "An update is already running – try again in a minute"
}

SPACE_REQ=66560  # ~65 MB

#-----------------------------------------------------------------------

check_existing() {
  # if there's already a tunnel configured, ask what to do. This only reads
  # the answer and records it; the backup or deletion happens later in
  # commit_existing_decision, once the lock is held.
  [ -d /etc/cloudflared ] && { [ -f /etc/cloudflared/config.yml ] || [ -f /etc/cloudflared/tunnel-token ]; } || return 0
  print_error "Existing tunnel config found in /etc/cloudflared/"
  print_info "  u) Upgrade in place – keep the tunnel, refresh the service, updater and boot hook"
  print_info "  o) Overwrite – delete the config and set up a new tunnel"
  print_info "  n) Leave it alone and exit"
  print_prompt "Pick u, o or n [n]: "
  # no answer (EOF, stdin not a terminal) means n, never o
  read -r answer || answer=n
  case "$answer" in
    [Uu]*) UPGRADE_ONLY=1; EXISTING_ACTION=upgrade ;;
    [Oo]*) EXISTING_ACTION=overwrite ;;
    *) print_info "Leaving existing config alone."; trap - EXIT; exit 0 ;;
  esac
}

# carry out the choice from check_existing and drop any OpenWrt package
# build of cloudflared. Runs only once the lock is held, so it can't race
# a background update that is touching the same files, and nothing
# destructive has happened if we failed to take the lock.
commit_existing_decision() {
  if [ "$EXISTING_ACTION" = upgrade ]; then
    BACKUP_DIR="/root/cloudflared-backup-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    for f in /etc/init.d/cloudflared /usr/sbin/cloudflared-update; do
      [ -f "$f" ] && cp -a "$f" "$BACKUP_DIR"/
    done
    print_info "Old service and updater scripts saved in $BACKUP_DIR"
  elif [ "$EXISTING_ACTION" = overwrite ]; then
    pgrep cloudflared >/dev/null 2>&1 && {
      print_info "Stopping running service..."
      /etc/init.d/cloudflared stop 2>/dev/null || true
    }
    rm -rf /etc/cloudflared
    rm -f /usr/sbin/cloudflared /usr/sbin/cloudflared-update
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

# --token-file needs cloudflared 2025.4.0 or newer. An upgrade in place
# keeps whatever binary is on the box, so check it before the init
# script starts depending on the flag. Anything we can't read a version
# out of counts as too old.
binary_too_old() {
  v=$(/usr/sbin/cloudflared -v 2>/dev/null | awk '{print $3}')
  case "$v" in
    [0-9][0-9][0-9][0-9].[0-9]*) ;;
    *) return 0 ;;
  esac
  y=${v%%.*}
  rest=${v#*.}
  m=${rest%%.*}
  [ "$y" -lt 2025 ] || { [ "$y" -eq 2025 ] && [ "$m" -lt 4 ]; }
}

# nano is only there so local-mode users have something nicer than vi
# for editing config.yml. Nothing else is needed beyond busybox.
install_packages() {
  print_info "Installing dependencies via $PKG_MGR..."
  if [ "$PKG_MGR" = "apk" ]; then
    apk update
    for pkg in nano; do
      apk info -e "$pkg" >/dev/null 2>&1 || apk add "$pkg" || die "Failed to install $pkg"
    done
  else
    opkg update
    for pkg in nano; do
      opkg list-installed | grep -q "^$pkg " || opkg install "$pkg" || die "Failed to install $pkg"
    done
  fi
  print_info "Done."
}

# fetch the latest cloudflared into $2 and verify it against the release's
# published SHA-256 before trusting it, the same checks the updater runs.
# Resolves the exact tag through the API rather than the latest redirect so
# there is a digest to compare against.
download_verified() {
  _dir=$1; _out=$2
  _json="$_dir/release.json"
  fetch https://api.github.com/repos/cloudflare/cloudflared/releases/latest "$_json" \
    || die "Couldn't fetch release info from GitHub"
  _tag=$(sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' "$_json" | head -n1)
  [ -n "$_tag" ] || die "Couldn't work out the latest version"
  _asset="cloudflared-linux-$INSTALL_TYPE"
  _digest=$(awk -v want="$_asset" '
    $0 ~ "\"name\": *\"" want "\"" { hit = 1 }
    hit && /"digest":/ { sub(/.*"sha256:/, ""); sub(/".*/, ""); print; exit }' "$_json")
  case "$_digest" in
    ????????????????????????????????????????????????????????????????) ;;
    *) die "Release $_tag has no sha256 digest for $_asset" ;;
  esac
  fetch "https://github.com/cloudflare/cloudflared/releases/download/$_tag/$_asset" "$_out" \
    || die "Download failed"
  _sum=$(sha256sum "$_out" | awk '{print $1}')
  [ "$_sum" = "$_digest" ] || die "Checksum mismatch for $_asset (got $_sum, release says $_digest)"
  chmod 755 "$_out"
  "$_out" -v >/dev/null 2>&1 || die "Downloaded binary doesn't run (truncated download or wrong architecture?)"
  print_info "Verified cloudflared $_tag against its published SHA-256."
}

install_cloudflared() {
  print_info "Downloading cloudflared for $INSTALL_TYPE..."
  WORKDIR=$(mktemp -d /tmp/cloudflared-install.XXXXXX) || die "Couldn't create a temp directory"
  chmod 700 "$WORKDIR"
  download_verified "$WORKDIR" "$WORKDIR/cloudflared"
  # copy it onto the same filesystem first so the final step is a plain
  # rename; a move straight out of tmpfs can leave half a binary behind
  cp "$WORKDIR/cloudflared" /usr/sbin/cloudflared.new || die "Couldn't copy the binary into /usr/sbin"
  mv /usr/sbin/cloudflared.new /usr/sbin/cloudflared
  sync
  rm -rf "$WORKDIR"
  WORKDIR=""
  print_info "Installed to /usr/sbin/cloudflared"
}

setup_tunnel() {
  echo
  while true; do
    print_info "Tunnel type:"
    print_info "  1) Locally managed"
    print_info "  2) Web console managed"
    print_prompt "Pick 1 or 2 (q to cancel): "
    read -r choice || die "Cancelled."
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

  print_prompt "Tunnel name (no spaces): "; read -r TUNNAME || die "Cancelled."
  cloudflared tunnel create "$TUNNAME"
  print_prompt "Domain (e.g. sub.domain.com): "; read -r DOMAIN || die "Cancelled."

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
  chmod 700 /etc/cloudflared
  print_info "Create a tunnel in Zero Trust and paste the token below (it won't echo)."
  print_prompt "Tunnel token: "
  stty -echo 2>/dev/null || true
  read -r token || token=""
  stty echo 2>/dev/null || true
  echo
  [ -n "$token" ] || die "No token entered."
  # umask in a subshell so the file is never world-readable, not even briefly
  ( umask 077; printf '%s\n' "$token" > /etc/cloudflared/tunnel-token )
  chmod 600 /etc/cloudflared/tunnel-token
  print_info "Token saved to /etc/cloudflared/tunnel-token (root only)."
}

# tighten up anything secret under /etc/cloudflared – safe to run on
# an existing install, which is how older boxes get fixed up
lock_down_secrets() {
  [ -d /etc/cloudflared ] || return 0
  chmod 700 /etc/cloudflared
  for f in /etc/cloudflared/tunnel-token /etc/cloudflared/*.json; do
    [ -f "$f" ] && chmod 600 "$f"
  done
  return 0
}

configure_service() {
  print_info "Writing init.d service..."
  lock_down_secrets

  # --token-file keeps the token out of ps and ubus output; the old
  # $(cat ...) form put it on the command line for anyone to read
  if [ -f /etc/cloudflared/tunnel-token ]; then
    cmd="/usr/sbin/cloudflared tunnel --no-autoupdate run --token-file /etc/cloudflared/tunnel-token"
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
# cloudflared-update – grab the latest cloudflared from GitHub and swap it in.
# Downloads and checks the new binary first, so the tunnel is only down for
# the swap itself. Boxes short on RAM stop the tunnel before downloading
# instead (the download sits in tmpfs), which is what this script always
# used to do.

# colour only when someone is watching; cron and syslog get plain text
if [ -t 1 ]; then G="\033[0;32m"; R="\033[0;31m"; N="\033[0m"; else G=""; R=""; N=""; fi
log() { printf "${G}%s${N}\n" "$1"; logger -t cloudflared-update "$1"; }
err() { printf "${R}%s${N}\n" "$1" >&2; logger -t cloudflared-update -p user.err "$1"; }

# during restore (CLOUDFLARED_RESTORE_DEADLINE set) limit each download to
# the time left. timeout targets the downloader directly so ash can resume
# and run cleanup; outside restore it runs plainly.
run_fetch() {
  if [ -n "${CLOUDFLARED_RESTORE_DEADLINE:-}" ]; then
    command -v timeout >/dev/null 2>&1 || { err "timeout is required for bounded restore – not updating"; return 1; }
    remaining=$(( CLOUDFLARED_RESTORE_DEADLINE - $(date +%s) ))
    [ "$remaining" -gt 0 ] || return 1
    timeout -k 5 "$remaining" "$@"
  else
    "$@"
  fi
}

# download $1 to file $2 with whatever fetcher works (wget, then curl).
# Both give up on a stalled connection rather than hanging forever.
fetch() {
  if command -v wget >/dev/null 2>&1 && run_fetch wget -q -T 60 -O "$2" "$1"; then
    return 0
  fi
  if command -v curl >/dev/null 2>&1 && run_fetch curl -fsSL --connect-timeout 30 --speed-limit 1024 --speed-time 60 -o "$2" "$1"; then
    return 0
  fi
  return 1
}

stop_tunnel() {
  # mark stopped before we touch the service, so an interruption during the
  # stop still routes through cleanup and brings the tunnel back
  STOPPED=1
  /etc/init.d/cloudflared stop
  sleep 1
  # BusyBox pgrep -x won't match the daemon, so match its unique command line
  pgrep -f "cloudflared tunnel" >/dev/null 2>&1 && killall -q cloudflared
}

# start the service and confirm the daemon is really up before trusting it
start_tunnel() {
  /etc/init.d/cloudflared start || { err "Service failed to start"; return 1; }
  sleep 2
  pgrep -f "cloudflared tunnel" >/dev/null 2>&1 || { err "cloudflared is not running after start – check logread"; return 1; }
  STARTED=1
  return 0
}

mem_available() { awk '/^MemAvailable:/ {print $2}' /proc/meminfo; }
free_kb() { df -k "$1" | awk 'NR==2 {print $4}'; }

INSTALL_TYPE=__INSTALL_TYPE__
BIN=/usr/sbin/cloudflared
NEWBIN="$BIN.new"
LOCK=/var/lock/cloudflared-update.lock
HEADROOM_KB=24576   # RAM to leave spare beyond the download itself
WORKDIR=""
STOPPED=0
STARTED=0

# one update at a time: cron, the restore hook and a manual run can
# otherwise all go at once and restart the tunnel under each other. require
# flock; it holds the lock on an open fd and the kernel releases it on any
# exit, so there's no stale lock to clean up. keep the lock file.
command -v flock >/dev/null 2>&1 || { err "flock is required but missing – not updating"; exit 1; }
mkdir -p "$(dirname "$LOCK")" || { err "Couldn't create the lock directory"; exit 1; }
exec 9>"$LOCK"
flock -n 9 || { err "Another update is already running"; exit 1; }

# tidy up on every exit, and never leave the tunnel stopped if we bailed
# out part way. ash doesn't run the EXIT trap when a signal kills the
# shell, so the signal traps turn into an exit and land here as well.
cleanup() {
  rc=$?
  [ -n "$WORKDIR" ] && rm -rf "$WORKDIR"
  rm -f "$NEWBIN"
  # if we stopped the tunnel and never confirmed it back up, start whatever
  # binary is in place now – the old one if we hadn't swapped yet, the new
  # one if we had. Covers an interrupted run at any point after the stop.
  if [ "$STOPPED" -eq 1 ] && [ "$STARTED" -eq 0 ]; then
    err "Tunnel was stopped and not confirmed back up – starting it"
    /etc/init.d/cloudflared start
  fi
  exit "$rc"
}
trap cleanup EXIT
trap 'err "Interrupted"; exit 130' INT
trap 'err "Terminated"; exit 143' TERM HUP

WORKDIR=$(mktemp -d /tmp/cloudflared-update.XXXXXX) || { err "Couldn't create a temp directory"; exit 1; }
chmod 700 "$WORKDIR"
TMPFILE="$WORKDIR/cloudflared"
TMPJSON="$WORKDIR/release.json"

fetch https://api.github.com/repos/cloudflare/cloudflared/releases/latest "$TMPJSON" \
  || { err "Couldn't fetch release info from GitHub"; exit 1; }
LATEST=$(sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' "$TMPJSON" | head -n1)
[ -n "$LATEST" ] || { err "Couldn't work out the latest version"; exit 1; }

# size and sha256 of our asset, both from the release's asset list. The
# size says how much tmpfs the download needs; the digest lets us check
# the file before running it.
ASSET="cloudflared-linux-$INSTALL_TYPE"
SIZE=$(awk -v want="$ASSET" '
  $0 ~ "\"name\": *\"" want "\"" { hit = 1 }
  hit && /"size":/ { gsub(/[^0-9]/, ""); print; exit }' "$TMPJSON")
case "$SIZE" in
  ''|*[!0-9]*) SIZE_KB=40960 ;;   # couldn't read it, assume ~40 MB
  *) SIZE_KB=$((SIZE / 1024)) ;;
esac
DIGEST=$(awk -v want="$ASSET" '
  $0 ~ "\"name\": *\"" want "\"" { hit = 1 }
  hit && /"digest":/ { sub(/.*"sha256:/, ""); sub(/".*/, ""); print; exit }' "$TMPJSON")
case "$DIGEST" in
  ????????????????????????????????????????????????????????????????) ;;
  *) err "Release $LATEST has no sha256 digest for $ASSET – not updating"; exit 1 ;;
esac

OLD=$("$BIN" -v 2>/dev/null | awk '{print $3}')
log "Installed: ${OLD:-none}  Latest: $LATEST"
if [ "$OLD" = "$LATEST" ]; then
  # right version already, but a previous run may have swapped the binary
  # and then failed to start it, so make sure it is actually running
  if pgrep -f "cloudflared tunnel" >/dev/null 2>&1; then
    log "Already up to date."
    exit 0
  fi
  log "Already up to date but not running – starting it"
  start_tunnel || exit 1
  exit 0
fi

# the download lands in /tmp (RAM), which has its own ceiling, usually
# half of memory, and no amount of stopping things will raise that
TMP_KB=$(free_kb /tmp)
if [ -n "$TMP_KB" ] && [ "$TMP_KB" -lt "$SIZE_KB" ]; then
  err "Only $TMP_KB kB free in /tmp, the download needs $SIZE_KB kB"
  exit 1
fi

# if there isn't room for the download alongside the running tunnel,
# stop the tunnel first to free up its memory, then look again
AVAIL_KB=$(mem_available)
NEED_KB=$((SIZE_KB + HEADROOM_KB))
if [ -z "$AVAIL_KB" ] || [ "$AVAIL_KB" -lt "$NEED_KB" ]; then
  log "Only ${AVAIL_KB:-?} kB free, need about $NEED_KB kB – stopping the tunnel before downloading"
  stop_tunnel
  AVAIL_KB=$(mem_available)
  if [ -n "$AVAIL_KB" ] && [ "$AVAIL_KB" -lt "$NEED_KB" ]; then
    err "Still only $AVAIL_KB kB free with the tunnel stopped – not enough for the download"
    exit 1
  fi
fi

log "Downloading cloudflared $LATEST…"
fetch "https://github.com/cloudflare/cloudflared/releases/download/$LATEST/$ASSET" "$TMPFILE" \
  || { err "Download failed"; exit 1; }

SUM=$(sha256sum "$TMPFILE" | awk '{print $1}')
[ "$SUM" = "$DIGEST" ] || { err "Checksum mismatch for $ASSET (got $SUM, release says $DIGEST) – not installing"; exit 1; }
chmod 755 "$TMPFILE"

# run it once as well – catches a wrong-arch asset with a matching digest
NEW=$("$TMPFILE" -v 2>/dev/null | awk '{print $3}')
[ "$NEW" = "$LATEST" ] || { err "Downloaded binary reports '${NEW:-nothing}', expected '$LATEST' – not installing"; exit 1; }

# stage the new binary next to the installed one while the tunnel is still
# up, so the swap itself is an atomic rename on one filesystem. If there
# isn't room to stage, keep the installed binary rather than risk a
# half-written one from an interrupted in-place cross-filesystem copy.
BIN_KB=$(free_kb "$(dirname "$BIN")")
if [ -z "$BIN_KB" ] || [ "$BIN_KB" -lt "$SIZE_KB" ]; then
  err "Only ${BIN_KB:-?} kB free beside $BIN, need $SIZE_KB kB to stage safely – keeping the installed binary"
  exit 1
fi
cp "$TMPFILE" "$NEWBIN" && chmod 755 "$NEWBIN" && sync \
  || { err "Couldn't stage the new binary at $NEWBIN"; exit 1; }

[ "$STOPPED" -eq 1 ] || stop_tunnel
mv "$NEWBIN" "$BIN" || { err "Couldn't rename $NEWBIN over $BIN"; exit 1; }
sync
start_tunnel || exit 1
log "Updated ${OLD:-none} -> $NEW"
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

# sysupgrade only keeps /etc/config and whatever is listed in
# /etc/sysupgrade.conf, so register the small bits. The 37 MB binary
# stays out on purpose (the backup tarball is built in RAM) and gets
# re-downloaded by the rc.local hook below.
setup_sysupgrade_keep() {
  print_info "Registering cloudflared files to survive sysupgrade..."
  touch /etc/sysupgrade.conf
  for f in /etc/cloudflared/ /etc/init.d/cloudflared /usr/sbin/cloudflared-update; do
    grep -qxF "$f" /etc/sysupgrade.conf || printf '%s\n' "$f" >> /etc/sysupgrade.conf
  done
}

# after a sysupgrade the binary and the rc.d links are gone. rc.local
# survives, so put a hook there that fetches the binary back and
# re-enables the service on first boot. Does nothing on a normal boot.
setup_restore_hook() {
  print_info "Installing post-sysupgrade restore hook in /etc/rc.local..."
  [ -f /etc/rc.local ] || printf '#!/bin/sh\nexit 0\n' > /etc/rc.local
  if grep -q 'cloudflared-restore-hook' /etc/rc.local; then
    print_info "Hook already there."
    return 0
  fi
  # drop the trailing exit 0, add the hook, put exit 0 back
  sed -i '/^exit 0[[:space:]]*$/d' /etc/rc.local
  cat <<'EOF' >> /etc/rc.local
# --- cloudflared-restore-hook (added by install-cloudflared.sh, removed by uninstall-cloudflared.sh) ---
# Binary missing means we just came through a sysupgrade. Re-enable the
# service, wait for DNS, then fetch the binary with the normal updater,
# which verifies it and starts the tunnel itself. The deadline is passed in
# the environment and the updater bounds each download with timeout against
# the time left, so a stalled transfer is cut off. This is a download
# deadline, not a hard bound on the whole restore: a cut-off download has a
# five-second kill grace, and the updater still has to finish a swap and
# start the tunnel, so the last attempt can run a little past it.
# Backgrounded so boot isn't held up. Log: /tmp/cloudflared-restore.log
if [ ! -x /usr/sbin/cloudflared ] && [ -x /usr/sbin/cloudflared-update ]; then
  (
    LOG=/tmp/cloudflared-restore.log
    echo "$(date) cloudflared binary missing - restoring after sysupgrade" >> "$LOG"
    /etc/init.d/cloudflared enable
    deadline=$(( $(date +%s) + 900 ))
    until nslookup api.github.com >/dev/null 2>&1 || [ "$(date +%s)" -ge "$deadline" ]; do sleep 10; done
    ok=0
    while [ "$(date +%s)" -lt "$deadline" ]; do
      if CLOUDFLARED_RESTORE_DEADLINE="$deadline" /usr/sbin/cloudflared-update >> "$LOG" 2>&1; then ok=1; break; fi
      sleep 30
    done
    if [ "$ok" -eq 1 ]; then
      echo "$(date) restore finished - tunnel updated and started" >> "$LOG"
    else
      echo "$(date) restore FAILED - no success before the deadline, run /usr/sbin/cloudflared-update by hand" >> "$LOG"
      logger -t cloudflared-restore -p user.err "could not fetch cloudflared after sysupgrade, run cloudflared-update by hand"
    fi
  ) &
fi
# --- end cloudflared-restore-hook ---
EOF
  printf 'exit 0\n' >> /etc/rc.local
  chmod 755 /etc/rc.local
}

#-----------------------------------------------------------------------
# main
#-----------------------------------------------------------------------

print_info "=== Cloudflared Installer ==="
print_info "Using $PKG_MGR"

check_existing
# acquire the lock before arming rollback or changing the install
take_lock
[ "$UPGRADE_ONLY" -eq 1 ] || FRESH_INSTALL=1
# ash doesn't run the EXIT trap when a signal kills the shell, so turn the
# usual ones into an exit and let the EXIT trap do the rest
trap 'rc=$?; [ "$rc" -ne 0 ] && rollback' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM HUP
commit_existing_decision
check_arch
install_packages
if [ "$UPGRADE_ONLY" -eq 1 ]; then
  print_info "Upgrade in place: keeping /etc/cloudflared and the installed binary."
  if [ ! -x /usr/sbin/cloudflared ]; then
    # happens when we're here after a sysupgrade
    print_info "Binary is missing, fetching it."
    check_space
    install_cloudflared
  elif [ -f /etc/cloudflared/tunnel-token ] && binary_too_old; then
    print_info "Installed cloudflared is older than 2025.4.0 and can't read a token file, replacing it."
    check_space
    install_cloudflared
  fi
else
  check_space
  install_cloudflared
  setup_tunnel
fi
configure_service
setup_updater
setup_sysupgrade_keep
setup_restore_hook

echo
print_prompt "Enable daily auto-update via cron? [y/N]: "
read -r AUTOUPDATE || AUTOUPDATE=n
case "$AUTOUPDATE" in
  [Yy]*) setup_cron ;;
  *) print_info "Skipped. Run '/usr/sbin/cloudflared-update' to update manually." ;;
esac

echo
if [ "$UPGRADE_ONLY" -eq 1 ]; then
  # restart so the rewritten init script takes effect
  print_info "Restarting service…"
  /etc/init.d/cloudflared restart
else
  print_info "Starting service…"
  /etc/init.d/cloudflared start
fi

print_info "All done."
trap - EXIT
exit 0
