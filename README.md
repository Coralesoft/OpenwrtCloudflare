# OpenWrt Cloudflare Tunnel Installer and Uninstaller v2026.10.0

Scripts to install, configure and uninstall Cloudflare Tunnels on OpenWrt, for Raspberry Pi, aarch64 based routers (GL.iNet GL-MT6000) and x86_64 platforms. Downloads cloudflared directly from GitHub and handles tunnel setup and service configuration.

## What's included
1. **`install-cloudflared.sh`** – Downloads cloudflared, walks through tunnel setup (local or web-managed), sets up the init.d service, installs an updater with optional daily cron, and adds a post-sysupgrade restore hook.
2. **`uninstall-cloudflared.sh`** – Removes everything: service, binary, updater, configs, cron job, and the sysupgrade keep-list entries and boot hook.

## Prerequisites
- Raspberry Pi, aarch64 based routers or x86_64 running OpenWrt 24.10+ (opkg) or 25.12+ (apk)
- Root access
- Internet connection
- `flock` (the installer and updater use it to stop runs overlapping) and, for the automatic post-sysupgrade restore, `timeout` with `-k`. Both are standard BusyBox applets on OpenWrt, but they must also be present in the firmware you flash.

## Installation
Run these on the router as root (OpenWrt logs you in as root, so there's no `sudo`).

### Quick Start
```sh
wget https://raw.githubusercontent.com/Coralesoft/OpenwrtCloudflare/main/install-cloudflared.sh
chmod +x install-cloudflared.sh
./install-cloudflared.sh
```

### Step by step
1. Download the installer:
   ```sh
   wget https://raw.githubusercontent.com/Coralesoft/OpenwrtCloudflare/main/install-cloudflared.sh
   ```
2. Make it executable:
   ```sh
   chmod +x install-cloudflared.sh
   ```
3. Run it:
   ```sh
   ./install-cloudflared.sh
   ```
4. Follow the prompts – pick local or web-managed, enter your tunnel details, optionally enable daily auto-updates.

### Already installed? Upgrade in place
Run the installer again on a box that already has a tunnel and it offers three choices: `u` upgrades in place (keeps your tunnel and token, rewrites the service and updater, and adds the boot hook if it isn't already there), `o` wipes the config and starts over, `n` exits. Pick `u` to get new script versions without re-entering anything. The old service and updater scripts are kept in `/root/cloudflared-backup-<date>/` in case you want them back.

## Uninstallation

### Quick Start
```sh
wget https://raw.githubusercontent.com/Coralesoft/OpenwrtCloudflare/main/uninstall-cloudflared.sh
chmod +x uninstall-cloudflared.sh
./uninstall-cloudflared.sh
```

### Step by step
1. Download the uninstaller:
   ```sh
   wget https://raw.githubusercontent.com/Coralesoft/OpenwrtCloudflare/main/uninstall-cloudflared.sh
   ```
2. Make it executable:
   ```sh
   chmod +x uninstall-cloudflared.sh
   ```
3. Run it:
   ```sh
   ./uninstall-cloudflared.sh
   ```

## Updating

### Automatic
If you enabled the cron job during install, cloudflared is checked daily at 12:30 (router local time) and updated if a new release is out.

### Manual
```sh
/usr/sbin/cloudflared-update
```

The updater downloads the new binary, checks it against the SHA-256 digest GitHub publishes for the release and runs it once to confirm the version, all before it stops the tunnel. Where there's room to download first this cuts the downtime to about the restart; on boxes short of RAM it stops the tunnel first instead, since the download sits in `/tmp`, so there the tunnel is also down for the download. Each run is logged to syslog, so `logread -e cloudflared-update` shows what happened. Only one update runs at a time, protected by `flock`, so the daily cron job and a manual run won't tread on each other.

On a 128 MB router the updater needs roughly 40 MB of free RAM for the download plus a margin, currently 24 MB. That margin is an estimate and 128 MB devices are untested, so treat the numbers as a starting point. It also needs enough free flash to stage a second copy of the binary beside the installed one for the swap. If it can't meet either, it logs the shortfall and leaves the installed binary in place rather than risk an out-of-memory kill or a half-written binary.

## Firmware upgrades
`sysupgrade` wipes everything that isn't configuration, including the 37 MB cloudflared binary. The installer lists its small files in `/etc/sysupgrade.conf` and adds a hook to `/etc/rc.local` that, on the first boot after a flash, re-enables the service, fetches the binary again and starts the tunnel. This only works if the upgrade keeps settings (the default), since the keep-list and the hook are themselves preserved that way, and the firmware you flash has to include `flock`, `timeout` and `wget`. It keeps trying for about fifteen minutes, give or take the time a final download and tunnel start take to finish. Progress is written to `/tmp/cloudflared-restore.log`. If every download attempt fails (no internet on first boot, say), the log ends in a line saying so and the same error goes to syslog, so re-run `/usr/sbin/cloudflared-update` by hand once the box is online. This recovery is implemented and its parts are tested, but it has not yet been exercised through a real firmware upgrade, so on your first flash with 2026.10.0 keep a config backup and local access to the box. If you had already added your own restore hook to `/etc/rc.local`, take it out before running the installer or both will try to download.

## The tunnel token
Web-managed installs keep the token in `/etc/cloudflared/tunnel-token`, readable by root only, and hand it to cloudflared with `--token-file` so it never shows up in `ps` or `ubus call service list`. The installer hides the token as you paste it where `stty` is available; a few stripped-down BusyBox builds lack it, and there the token stays visible on screen while you type, so paste it somewhere private. Older versions of these scripts put it on the command line, so if you have ever pasted that output into a forum post or a ticket, rotate it: in the Cloudflare dashboard go to Networking, Tunnels, pick the tunnel and rotate its token, write the new token into `/etc/cloudflared/tunnel-token`, then `/etc/init.d/cloudflared restart`. Refreshing stops the old token opening **new** connections, but connectors already running on it stay up, so if you think the token is compromised also use **Delete all connections** on the same tunnel to drop the ones already running.

## Troubleshooting
- **Not enough space** – Installer checks for ~65 MB free and will tell you if there isn't enough.
- **Unsupported architecture** – Only aarch64 and x86_64 are supported.
- **Permission errors** – Run as root.
- **Install fails halfway through** – A fresh install cleans up what it created; an upgrade in place restores the backed-up service and updater scripts and leaves your tunnel and token alone.
- **Tunnel gone after a firmware upgrade** – Wait a few minutes and check `/tmp/cloudflared-restore.log`. If the hook isn't there (installed with a version before 2026.10.0), download the installer again and pick `u`.

## Support
For issues or feature requests, contact **C. Brown** at [dev@coralesoft.nz](mailto:dev@coralesoft.nz).

## Support the Project
If you find this useful, consider buying me a coffee:

<a href="https://www.buymeacoffee.com/r6zt79njh5m" target="_blank">
  <img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" alt="Buy Me A Coffee" style="height:60px;width:217px;" />
</a>

## License
MIT License – see `LICENSE` for details.

## Acknowledgements
Thanks to the OpenWrt and Cloudflare communities for their tools and documentation.
