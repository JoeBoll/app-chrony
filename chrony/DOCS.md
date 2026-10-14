# Chrony (NTP peering)

Fork of the Home Assistant Community App: chrony

An NTP server accessible by all hosts on the local network, useful for setting
time on devices with controlled internet access (such as cameras).
The app can also be used to set the system clock.

## About this fork

This is a fork of the community chrony app that adds **true NTP peering**
(chrony `peer` lines, a symmetric association where both hosts can serve
time to each other), symmetric-key authentication, allow lists, extra
servers, reference clock passthrough (for a future GPS/PPS hat) and a
free-form `extra_config` option. It installs as its own add-on,
**Chrony (NTP peering)** (slug `chrony_peering`), so it can sit next to the
community add-on. Do not run both at once: only one of them can own UDP 123
and set the clock.

## Installation

1. In Home Assistant open **Settings > Add-ons > Add-on Store**.
1. Open the three-dots menu (top right) > **Repositories**.
1. Add `https://github.com/JoeBoll/app-chrony` and close the dialog.
1. Refresh the store, find **Chrony (NTP peering)** and click **Install**.
   Home Assistant builds the image on the device from the Dockerfile (this
   compiles chrony and takes a few minutes on a Raspberry Pi).
1. Stop/uninstall the community **chrony** add-on if it is installed.
1. Fill in the **Configuration** tab (see below), save, then **Start**.
1. Check the **Log** tab: the rendered `chrony.conf` is printed at startup
   (the key file contents are never printed).

## Configuration

**Note**: _Restart the add-on after changing the configuration._

Example (one Pi peering with one host, plus a public pool as a backstop):

```yaml
set_system_clock: true
mode: pool
ntp_pool: pool.ntp.org
makestep_threshold: 0.1
makestep_limit: -1
default_minpoll: 4
default_maxpoll: 6
peers:
  - address: 192.0.2.10
    key: 1
    xleave: true
    minpoll: -6
    maxpoll: -6
    filter: 7
allow:
  - 192.0.2.0/24
keys:
  - id: 1
    type: SHA256
    secret: HEX:<64 hex digits, same as on the peer>
```

### Option: `log_level`

Add-on log verbosity: `trace`, `debug`, `info` (default), `notice`,
`warning`, `error`, `fatal`.

### Option: `set_system_clock`

When `true` (default) chrony disciplines the host clock (the add-on has the
`SYS_TIME` privilege, same as upstream). When `false` chronyd runs with `-x`
and only serves time; `makestep` is then ignored by chrony.

### Option: `mode`, `ntp_pool`, `ntp_server`

Upstream options, unchanged:

- `pool`: add `pool <ntp_pool> iburst`.
- `server`: add `server <name> iburst` for each `ntp_server` entry.
- `none` (new): no upstream pool/server; use only `peers`, `servers` and
  `refclocks`.

### Option: `makestep_threshold` / `makestep_limit`

Rendered as `makestep <threshold> <limit>`. The default `0.1 -1` steps the
clock whenever it is more than 0.1 s off, at any time (aggressive). Use e.g.
`1.0` / `3` for the conventional "step only at boot" behaviour.

### Option: `default_minpoll` / `default_maxpoll`

Poll range applied to every `peers`/`servers` entry that does not set its
own. Values are powers of two in seconds (4 = 16 s, 6 = 64 s). Defaults are
4 and 6. Keep public servers at 6 or higher.

### Option: `peers`

Symmetric NTP peers. Each entry renders
`peer <address> [key N] [xleave] [minpoll X] [maxpoll Y] [prefer]`.

| Key | Type | Notes |
| --- | --- | --- |
| `address` | str | IP or hostname |
| `key` | int | key id from `keys`; both sides must use the same id and secret |
| `xleave` | bool | interleaved mode; must be enabled on both peers |
| `minpoll` / `maxpoll` | int | overrides the defaults; -7 to 24 (power of two seconds, so -6 = 64 polls per second) |
| `filter` | int | median filter over N polls (`filter N`); useful with sub-second polling |
| `iburst` | bool | **ignored with a warning**: chrony does not support `iburst` (or `burst`, `nts`, `presend`, `copy`) on `peer` lines |
| `prefer` | bool | prefer this source |

chrony's own docs note that symmetric mode is weaker than client/server
mode, and that unauthenticated peers can be disrupted by spoofed packets.
Always use a `key` for peers.

Sub-second polling (negative minpoll/maxpoll) is meant for a wired LAN:
chrony only enables it when the source is reachable and the round-trip
delay is under 10 ms; otherwise it polls at 1 s. Both peers should use the
same poll interval. Combine it with `filter` (e.g. `filter 7`) to merge
the many samples into one per update. If you only need both hosts to be able to
sync from each other, two `server` lines (one on each host) is the
alternative chrony recommends.

### Option: `servers`

Extra client/server sources, same keys as `peers`; here `iburst` is valid
and rendered.

### Option: `allow`

List of subnets or addresses allowed to query this server, e.g.
`192.0.2.0/24`. Each becomes `allow <entry>`. When empty, `allow all` is
rendered (upstream behaviour). A peer must be covered by an `allow` entry
on both sides.

### Option: `keys`

| Key | Type | Notes |
| --- | --- | --- |
| `id` | int | 1 to 2^32-1 |
| `type` | list | `MD5`, `SHA1`, `SHA256`, `SHA384`, `SHA512`, `AES128`, `AES256` |
| `secret` | password | `HEX:...` (recommended) or a plain ASCII password without spaces; AES keys must be `HEX:` (32 hex digits for AES128, 64 for AES256) |

Keys are written to `/etc/chrony/chrony.keys` (mode 0600) and referenced by
a `keyfile` line. The secret is masked in the UI and never logged. Generate
one with `chronyc keygen 1 SHA256 256` on the Proxmox host (it prints a
complete key line) or `openssl rand -hex 32`.

### Option: `refclocks`

Raw refclock passthrough; for GPS use the `gps` option instead.
Each entry is appended as `refclock <entry>`, for example
`SHM 0 refid NMEA noselect` or `PPS /dev/pps0 lock NMEA refid PPS`.
chronyd exits if a PPS device does not exist, so only add PPS entries once
the device is mapped (see below).

### Option: `local_stratum`

Optional. Renders `local stratum N` so the add-on keeps serving time when
all sources are gone. Leave unset unless you want that.

### Option: `extra_config`

Free-form text appended at the end of `chrony.conf` (e.g. `log tracking`,
`logdir /data/chrony`, `hwtimestamp eth0`). It is printed in the log, so do
not put secrets here; use `keys`.

## Proxmox / peer host checklist

On each host this add-on peers with (Debian `chrony`):

1. Add the same key to `/etc/chrony/chrony.keys` (same id, type and
   secret), `chmod 640` and `chown root:_chrony`. Make sure
   `keyfile /etc/chrony/chrony.keys` is in `/etc/chrony/chrony.conf`
   (Debian ships it).
1. Add a matching peer line, e.g.
   `peer <pi address> key 1 xleave minpoll -6 maxpoll -6 filter 7`.
1. Add `allow <pi address>` (or its subnet).
1. Open UDP 123 between the hosts (Proxmox firewall at datacenter/node
   level if enabled, plus any LAN firewall).
1. `systemctl restart chrony`.

## Verifying

From the Pi, use the Terminal & SSH add-on with protection mode off, or
`docker exec -it addon_<repo-hash>_chrony_peering chronyc ...`; on the
Proxmox host run `chronyc` directly:

- `chronyc sources -v`: the peer shows mode `=` and a Reach value climbing
  to 377.
- `chronyc ntpdata <address>`: `Mode: Symmetric active`,
  `Authenticated: Yes`, `Interleaved: Yes` when xleave works.
- `chronyc authdata`: the peer with mode `SK`, the right key id and length.
- `chronyc tracking`: current offset and stratum.

## GPS / PPS reference clock

The image bundles gpsd 3.27. It only runs when `gps.enabled` is `true` and
`gps.serial_device` is set; otherwise its service idles.

### Option: `gps`

| Key | Type | Default | Notes |
| --- | --- | --- | --- |
| `enabled` | bool | `false` | master switch |
| `serial_device` | device (tty) | unset | GPS serial port, e.g. `/dev/ttyAMA0` or `/dev/serial0`; gpsd reads NMEA from it |
| `pps_device` | device | unset | normally `/dev/pps0` |
| `baud` | int | unset | gpsd autodetects when unset |
| `nmea_source` | `shm` / `sock` | `shm` | how gpsd hands NMEA time to chrony |
| `nmea_offset` / `nmea_delay` | float | `0.2` / `0.2` | tune `nmea_offset` against PPS once it is locked |
| `pps_offset` | float | unset | cable/receiver correction in seconds |
| `pps_prefer` | bool | `true` | add `prefer` to the PPS refclock |

With a serial port and PPS this renders:

```text
refclock SHM 0:perm=0666 refid NMEA noselect offset 0.2 delay 0.2
refclock PPS /dev/pps0 lock NMEA refid PPS prefer
```

The NMEA source is `noselect` and only numbers the seconds; PPS is the
real (preferred) time source. `perm=0666` is needed because gpsd drops
root after opening the port; the segment lives in the add-on's private
IPC namespace. With `nmea_source: sock` chrony creates
`/run/chrony.clk.<tty>.sock` and gpsd (started after chrony) writes to it.
Without PPS the NMEA source is left selectable. With PPS but no serial port
the PPS refclock has no `lock` and chrony numbers the seconds from the
network sources.

### Device access (why there is no `devices:` list)

Home Assistant mounts the host `/dev` read-only into every add-on and
grants access per device through cgroup rules. Older Supervisor versions
refused to start an add-on whose static `devices:` entry was missing, so
this add-on does not use one:

- `uart: true` grants access to all serial ports (gpsd).
- `gps.pps_device` uses the `device` option type, so the PPS device is
  picked from a drop-down and granted only when it is set. Leave it empty
  on a Pi without a GPS hat.
- If `pps_device` is set but missing at startup (hat removed), the PPS line
  is skipped with a warning instead of letting chronyd exit.

### Enabling an Adafruit Ultimate GPS hat (later)

1. Shut down, fit the hat and antenna.
1. Edit `config.txt` on the HAOS boot partition: `dtoverlay=pps-gpio,gpiopin=4`,
   and free the UART (`enable_uart=1`; on a Pi 3/4/5 also
   `dtoverlay=disable-bt`, or use `/dev/ttyAMA0`/`serial0` as appropriate).
   Reboot and confirm `/dev/pps0` and the serial port appear under
   Settings > System > Hardware. Whether the `pps-gpio` module is present
   in a given HAOS kernel has not been verified.
1. In the add-on set `gps.enabled: true`, pick `serial_device` and
   `pps_device`, restart, then watch `chronyc sources` until `PPS` shows
   `*` and `NMEA` shows reach 377.
1. Tune `nmea_offset` so the NMEA offset in `chronyc sourcestats` is
   close to zero.

## Performance options

### Option: `hwtimestamp`

Renders `hwtimestamp *` (NIC hardware timestamping on all interfaces that
support it). It helps on a Raspberry Pi 5 wired Ethernet port, which has a
PTP hardware clock; the Pi 4's Ethernet does not do hardware timestamping.
Interfaces without support are ignored and chronyd starts normally.

### Option: `lock_all`

Renders `lock_all` (keep chronyd in RAM). Uses the `IPC_LOCK` and
`SYS_RESOURCE` privileges granted to the add-on.

### Option: `sched_priority`

Renders `sched_priority N` (SCHED_FIFO real-time priority, 1-99, default
1; 0 disables it). The add-on requests `SYS_NICE` and `realtime: true`
(Supervisor adds the rtprio ulimit and an RT CPU budget). If the kernel
refuses, chronyd keeps running at normal priority: with musl the failure
is not even logged, so it is hard to see if it took effect.

## Deployment notes

- Use wired Ethernet, on the same switch as the Proxmox host it peers with.
  Wi-Fi jitter wastes sub-second polling.
- CPU frequency: HAOS uses the `ondemand` cpufreq governor and has no
  setting to change it; add-ons cannot write to `/sys`. The only lever is
  the Raspberry Pi firmware: `force_turbo=1` in `config.txt` pins the CPU
  at its maximum clock (no overvolt, so it does not set the warranty bit),
  at the cost of heat and power. This has not been tested here.
- Intended layout per house: with a PPS hat each Pi becomes the house's
  preferred local stratum 1 source; the Proxmox host peers with it on the
  LAN and otherwise prefers public NTS servers; the cross-site link over
  Tailscale is a backup peer only (higher poll, no `prefer`).

## Changelog

See [CHANGELOG.md](CHANGELOG.md).

## Authors & contributors

The original chrony add-on is by Paul Sinclair. This fork is maintained by
Joe Boll.

## License

MIT License

Copyright (c) 2019-2026 Paul Sinclair

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
