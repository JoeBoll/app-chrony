> **Fork notice:** this is Joe Boll's fork of the Home Assistant Community
> Apps chrony app. It adds true NTP peering (`peer` lines), authentication
> keys, allow lists, extra servers, refclock passthrough and an
> `extra_config` escape hatch. It installs as a separate add-on,
> **Chrony (NTP peering)** (`chrony_peering`), so it does not clash with the
> community add-on. Add `https://github.com/JoeBoll/app-chrony` as a
> repository in the add-on store, then see [chrony/DOCS.md](chrony/DOCS.md).
> Original work is MIT licensed by Paul Sinclair; see [LICENSE.md](LICENSE.md).

# Chrony (NTP peering)

Fork of the Home Assistant Community App: chrony.

Enjoying this add-on? Buy them a coffee: Paul Sinclair, maintainer of the
original Home Assistant chrony add-on.

[![Buy me a coffee][buymeacoffee-shield]][buymeacoffee]

## About

An NTP server accessible by all hosts on the local network, useful for setting
time on devices with controlled internet access (such as cameras).
The app can also be used to set the system clock. This fork adds symmetric
peering, authentication keys, GPS/PPS and tuning options.

[:books: Read the full add-on documentation](chrony/DOCS.md)

## Authors & contributors

The original chrony add-on is by Paul Sinclair. This fork is maintained by
Joe Boll. chrony itself is by Richard Curnow (original author) and
Miroslav Lichvar (maintainer).

[buymeacoffee-shield]: https://www.buymeacoffee.com/assets/img/guidelines/download-assets-sm-2.svg
[buymeacoffee]: https://www.buymeacoffee.com/sinclairpaul
