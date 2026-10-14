ARG BUILD_FROM=ghcr.io/hassio-addons/base:21.0.8

# Fork change: Alpine's chrony package is built without a crypto library
# (-SECHASH), so it only accepts MD5 NTP keys. Rebuild chronyd/chronyc with
# nettle so SHA1/SHA256/SHA512/AES128/AES256 keys work for peering.
# hadolint ignore=DL3006
FROM ${BUILD_FROM} AS chrony-build
ARG CHRONY_VERSION=4.8
ARG CHRONY_SHA256=33ea8eb2a4daeaa506e8fcafd5d6d89027ed6f2f0609645c6f149b560d301706
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
# hadolint ignore=DL3018
RUN \
    apk add --no-cache build-base curl libcap-dev nettle-dev \
    && curl -fsSL -o /tmp/chrony.tar.gz \
        "https://chrony-project.org/releases/chrony-${CHRONY_VERSION}.tar.gz" \
    && echo "${CHRONY_SHA256}  /tmp/chrony.tar.gz" | sha256sum -c - \
    && mkdir -p /tmp/chrony \
    && tar -xzf /tmp/chrony.tar.gz -C /tmp/chrony --strip-components=1 \
    && cd /tmp/chrony \
    && ./configure --prefix=/usr --sysconfdir=/etc/chrony \
        --with-user=chrony --disable-nts --without-gnutls \
        --without-editline --without-seccomp \
    && make -j"$(nproc)" \
    && ./chronyd -v | grep -q '+SECHASH'

# hadolint ignore=DL3006
FROM ${BUILD_FROM}

# Set shell
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Setup base
# hadolint ignore=DL3003
# hadolint ignore=DL3018
RUN \
    apk add --no-cache \
        chrony=4.8-r7 \
        gpsd=3.27.3-r1 \
        libcap \
        nettle

COPY --from=chrony-build /tmp/chrony/chronyd /usr/sbin/chronyd
COPY --from=chrony-build /tmp/chrony/chronyc /usr/bin/chronyc

# Copy root filesystem
COPY rootfs /

# Build arguments
ARG BUILD_ARCH
ARG BUILD_DATE
ARG BUILD_DESCRIPTION
ARG BUILD_NAME
ARG BUILD_REF
ARG BUILD_REPOSITORY
ARG BUILD_VERSION

# Labels
LABEL \
    io.hass.name="${BUILD_NAME}" \
    io.hass.description="${BUILD_DESCRIPTION}" \
    io.hass.arch="${BUILD_ARCH}" \
    io.hass.type="addon" \
    io.hass.version=${BUILD_VERSION} \
    maintainer="Joe Boll" \
    org.opencontainers.image.title="${BUILD_NAME}" \
    org.opencontainers.image.description="${BUILD_DESCRIPTION}" \
    org.opencontainers.image.vendor="Joe Boll (fork of Home Assistant Community Apps chrony)" \
    org.opencontainers.image.authors="Joe Boll; original add-on by Paul Sinclair" \
    org.opencontainers.image.licenses="MIT" \
    org.opencontainers.image.url="https://github.com/JoeBoll/app-chrony" \
    org.opencontainers.image.source="https://github.com/${BUILD_REPOSITORY}" \
    org.opencontainers.image.documentation="https://github.com/${BUILD_REPOSITORY}/blob/main/README.md" \
    org.opencontainers.image.created=${BUILD_DATE} \
    org.opencontainers.image.revision=${BUILD_REF} \
    org.opencontainers.image.version=${BUILD_VERSION}
