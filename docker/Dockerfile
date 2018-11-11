# Traefik Docker

# docker build . -t traefik
# docker run --name router -v $(pwd)/datadir:/etc/traefik  traefik

ARG ARCH=arm32v6
FROM "${ARCH}/alpine:3.8"

ARG VERSION=1.7.4
ARG MYVERSION=jose1
ARG CONFIGDIR=/etc/traefik
ARG UID=1000
ARG GUID=1000
ARG DEFAULTPORT=80
ARG TLSPORT=443
ARG APIPORT=8080
ARG TZ=Europe/Amsterdam
ARG ARCH

LABEL org.label-schema.docker.schema-version="1.0"
LABEL org.label-schema.vendor="Jose Riguera"
LABEL org.label-schema.description="A modern reverse-proxy for Docker and the Raspberry Pi."
LABEL org.label-schema.name="rpi-traefik"
LABEL org.label-schema.version="${VERSION}-${MYVERSION}"
LABEL org.label-schema.usage="/README.md"
LABEL org.label-schema.url="https://hub.docker.com/r/jriguera/rpi-traefik"
LABEL org.label-schema.vcs-url="https://github.com/jriguera/docker-rpi-traefik"
LABEL maintainer="Jose Riguera <jriguera@gmail.com>"
LABEL architecture="${ARCH}"

ENV LANG=en_US.utf8
ENV LC_ALL=C.UTF-8
ENV TRAEFIK_CONFIG="${CONFIGDIR}"
ENV TRAEFIK_PORT_DEFAULT="${DEFAULTPORT}"
ENV TRAEFIK_PORT_TLS="${TLSPORT}"
ENV TRAEFIK_PORT_API="${APIPORT}"

RUN set -xe                                                                 && \
    apk -U upgrade                                                          && \
    # User/group
    addgroup -g "${GUID}" -S traefik                                           && \
    adduser -h "${DATADIR}" -D -G traefik -s /sbin/nologin -u "${UID}" traefik && \
    # Installing Alpine packages
    apk add --no-cache \
        ca-certificates \
        pwgen \
        su-exec \
        tzdata \
        socat \
        net-tools \
        curl \
        bash \
                                                                            && \
    # Timezone
    cp "/usr/share/zoneinfo/${TZ}" /etc/localtime                           && \
    echo "${TZ}" > /etc/timezone                                            && \
    # clean up
    rm -rf /tmp/* /var/tmp/* /var/cache/apk/* /var/cache/distfiles/*

COPY *.sh /usr/local/bin/
COPY etc /etc/traefik

RUN set -xe                                                                 && \
    chmod a+x /usr/local/bin/*                                              && \
    ln -s /usr/local/bin/traefik.sh /usr/local/bin/docker-entrypoint.sh     && \
    ln -s /usr/local/bin/traefik.sh /docker-entrypoint.sh                   && \
    ln -s /usr/local/bin/traefik.sh /run.sh                                 && \
    mkdir -p /docker-entrypoint-initdb.d                                    && \
    mkdir -p "${CONFIGDIR}"                                                 && \
    chown -R traefik:traefik /etc/traefik

RUN set -ex                                                                 && \
    [ "${ARCH}" == "arm32v6" ] && wget --quiet -O /usr/bin/traefik "https://github.com/containous/traefik/releases/download/v$VERSION/traefik_linux-arm";                                                            \
    [ "${ARCH}" == "amd64" ] && wget --quiet -O /usr/bin/traefik "https://github.com/containous/traefik/releases/download/v$VERSION/traefik_linux-amd64";                                                          \
    chmod +x /usr/bin/traefik


VOLUME ["${CONFIGDIR}"]
EXPOSE "${DEFAULTPORT}" "${TLSPORT}" "${APIPORT}"

ENTRYPOINT ["/run.sh"]
# Define default command
CMD ["traefik"]

