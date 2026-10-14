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
| `minpoll` / `maxpoll` | int | overrides the defaults |
| `iburst` | bool | **ignored with a warning**: chrony does not support `iburst` (or `burst`, `nts`, `presend`, `copy`) on `peer` lines |
| `prefer` | bool | prefer this source |

chrony's own docs note that symmetric mode is weaker than client/server
mode, and that unauthenticated peers can be disrupted by spoofed packets.
Always use a `key` for peers. If you only need both hosts to be able to
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
   `peer <pi address> key 1 xleave minpoll 4 maxpoll 6`.
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

## GPS / PPS reference clock (later)

Not enabled yet. To add an Adafruit GPS hat later:

1. Enable PPS on the Pi (HAOS `config.txt`:
   `dtoverlay=pps-gpio,gpiopin=4`) and confirm `/dev/pps0` exists.
1. Map the devices: uncomment `devices:` in `config.yaml` (`/dev/pps0` and
   the GPS serial port) in a local copy of this add-on, or bump the add-on
   with that change. Home Assistant refuses to start an add-on whose mapped
   device is missing, which is why it is not mapped by default.
1. A time source for the PPS pulse is needed: gpsd is not bundled. Either
   run gpsd in another add-on writing to SHM (`refclocks: ["SHM 0 refid
   NMEA noselect", "PPS /dev/pps0 lock NMEA refid PPS"]`), or lock PPS to
   the network peers (`PPS /dev/pps0 refid PPS`, chrony completes the
   seconds from the other sources).

## Changelog & Releases

This repository keeps a change log using [GitHub's releases][releases]
functionality.

Releases are based on [Semantic Versioning][semver], and use the format
of `MAJOR.MINOR.PATCH`. In a nutshell, the version will be incremented
based on the following:

- `MAJOR`: Incompatible or major changes.
- `MINOR`: Backwards-compatible new features and enhancements.
- `PATCH`: Backwards-compatible bugfixes and package updates.

## Support

Got questions?

You have several options to get them answered:

- The [Home Assistant Community Apps Discord chat server][discord] for app
  support and feature requests.
- The [Home Assistant Discord chat server][discord-ha] for general Home
  Assistant discussions and questions.
- The Home Assistant [Community Forum][forum].
- Join the [Reddit subreddit][reddit] in [/r/homeassistant][reddit]

You could also [open an issue here][issue] GitHub.

## Authors & contributors

The original setup of this repository is by [Paul Sinclair][sinclairpaul].

For a full list of all authors and contributors,
check [the contributor's page][contributors].

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

[contributors]: https://github.com/hassio-addons/app-chrony/graphs/contributors
[discord-ha]: https://discord.gg/c5DvZ4e
[discord]: https://discord.me/hassioaddons
[forum]: https://community.home-assistant.io/t/community-hass-io-xxxxx/xxxxx
[issue]: https://github.com/hassio-addons/app-chrony/issues
[reddit]: https://reddit.com/r/homeassistant
[releases]: https://github.com/hassio-addons/app-chrony/releases
[semver]: http://semver.org/spec/v2.0.0.htm
[sinclairpaul]: https://github.com/sinclairpaul
