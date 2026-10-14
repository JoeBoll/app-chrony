# Changelog

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
