# Security Policy

The security of this project is taken seriously. We appreciate your efforts to
responsibly disclose any findings and will make every effort to acknowledge
your contributions.

## Supported Versions

Security updates are provided only for the latest released version of this
app. Users are strongly encouraged to keep their installations up to date.

| Version        | Supported          |
| -------------- | ------------------ |
| Latest release | :white_check_mark: |
| Older releases | :x:                |

## Reporting a Vulnerability

Report vulnerabilities in this fork by opening an issue at
<https://github.com/JoeBoll/app-chrony/issues>. Do not post exploit details
publicly: open the issue with a short summary and ask for a private channel,
and the maintainer (Joe Boll) will follow up.

Vulnerabilities that also affect the original add-on should be reported to
upstream (<https://github.com/hassio-addons/app-chrony>) following their
security policy.

When reporting, please include as much of the following as possible:

- A clear description of the vulnerability and its potential impact.
- Steps to reproduce, or a proof of concept.
- Affected version(s) of the app.
- Any known mitigations or workarounds.

## Disclosure Timeline

This is a personal fork maintained on a best-effort basis; there is no
guaranteed response time.

You will be kept informed throughout the process and credited in the release
notes for the fix, unless you prefer to remain anonymous.

## Out of Scope

The following are **not** considered security vulnerabilities in this project:

- Vulnerabilities in upstream or transitive dependencies. These are handled
  continuously by [Renovate](https://github.com/renovatebot/renovate) and
  addressed through regular dependency updates.
- Issues in the Alpine Linux base image or its packages; please report those
  to the [Alpine Linux project](https://gitlab.alpinelinux.org/alpine).
- Issues in chrony itself; please report those directly to the
  [chrony project](https://chrony-project.org/).
- Issues that require an already compromised Home Assistant instance, or
  access to the host the app runs on.

## Scope

This security policy covers the Chrony (NTP peering) add-on published from
https://github.com/JoeBoll/app-chrony (a fork of the Home Assistant
Community Apps chrony add-on) and its source code in this repository.
