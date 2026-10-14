# Changelog

## 6.1.0-peering.3

- Add a structured `gps` option: gpsd 3.27 bundled and started by s6 only
  when enabled; NMEA via SHM 0 or SOCK, PPS refclock locked to NMEA and
  preferred; offsets/delays tunable; missing PPS device is skipped with a
  warning.
- Device access via `uart: true` and a `device`-type `pps_device` option
  instead of static `devices:`, so a Pi without a GPS hat still starts.
- Add `hwtimestamp`, `lock_all` and `sched_priority` (default 1) options;
  add `SYS_NICE`, `IPC_LOCK`, `SYS_RESOURCE` privileges and `realtime: true`.
- Docs: deployment notes (wired Ethernet, CPU governor, stratum layout).

## 6.1.0-peering.2

- Add per-peer/server `filter` option (`filter N`).
- Validate minpoll/maxpoll range (-7..24, negative = sub-second polling)
  and that minpoll <= maxpoll.
- Docs example peer now uses `minpoll -6 maxpoll -6 xleave filter 7 key 1`.

## 6.1.0-peering.1

Fork of [hassio-addons/app-chrony](https://github.com/hassio-addons/app-chrony)
v6.1.0, published as a separate store add-on (slug `chrony_peering`).

- Add symmetric NTP peering (`peers`) with key, xleave, minpoll/maxpoll.
  `iburst` is accepted in the schema but dropped with a warning for peers,
  because chrony does not support it on `peer` lines.
- Add extra `servers` with key/xleave/poll/iburst/prefer options; the
  upstream `mode`/`ntp_pool`/`ntp_server` options still work, plus a new
  `none` mode for peer/server/refclock-only setups.
- Add `keys` (written to a 0600 key file, never logged), `allow` subnets,
  `refclocks` passthrough, `local_stratum` and free-form `extra_config`.
- Configurable `makestep` (default `0.1 -1`) and default poll range
  (default minpoll 4 / maxpoll 6).
- Use host networking so UDP 123 is served on the LAN and peers see the
  real source address.
- Rebuild chronyd/chronyc 4.8 from source with nettle: the Alpine package is
  built without hash support and only accepts MD5 keys.
- Log the rendered `chrony.conf` at startup and validate it with
  `chronyd -p` before starting.
- Persistent drift file in `/data/chrony/drift`.
