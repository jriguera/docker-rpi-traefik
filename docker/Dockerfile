# Traefik Docker

# docker build . -t traefik
# docker run -ti -p 8080:80 -p 8081:8080 -v $(pwd)/config:/config -e DOMAIN=localhost -e DOMAIN_ROUTE_DOCKERS=true -v /var/run/docker.sock:/var/run/docker.sock  traefik

ARG ARCH=arm32v6
FROM "${ARCH}/alpine:3.10"

ARG VERSION=2.0.4
ARG MYVERSION=jose0
ARG CONFIGDIR=/config

ARG UID=1000
ARG GUID=1000
ARG PORT_HTTP=80
ARG PORT_HTTPS=443
ARG PORT_API=8080
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
ENV CONFIGDIR="${CONFIGDIR}"
ENV PORT_HTTP="${PORT_HTTP}"
ENV PORT_HTTPS="${PORT_HTTPS}"
ENV PORT_API="${PORT_API}"

RUN set -xe                                                                 && \
    apk -U upgrade                                                          && \
    # User/group
    addgroup -g "${GUID}" -S traefik                                        && \
    adduser -h "${CONFIGDIR}" -D -G traefik -s /bin/bash -u"${UID}" traefik && \
    # Installing Alpine packages
    apk add --no-cache \
        ca-certificates \
        pwgen \
        su-exec \
        tzdata \
        socat \
        apache2-utils \
        net-tools \
        libcap \
        curl \
        bash \
                                                                            && \
    # Timezone
    cp "/usr/share/zoneinfo/${TZ}" /etc/localtime                           && \
    echo "${TZ}" > /etc/timezone                                            && \
    # clean up
    rm -rf /tmp/* /var/tmp/* /var/cache/apk/* /var/cache/distfiles/*

COPY *.sh /usr/local/bin/
RUN set -xe                                                                 && \
    chmod a+x /usr/local/bin/*                                              && \
    ln -s /usr/local/bin/traefik.sh /usr/local/bin/docker-entrypoint.sh     && \
    ln -s /usr/local/bin/traefik.sh /docker-entrypoint.sh                   && \
    ln -s /usr/local/bin/traefik.sh /run.sh                                 && \
    mkdir -p /docker-entrypoint-initdb.d                                    && \
    mkdir -p "${CONFIGDIR}"                                                 && \
    mkdir -p /etc/traefik                                                   && \
    chown -R traefik:traefik "${CONFIGDIR}" /etc/traefik

RUN set -ex                                                                 && \
    [ "${ARCH}" == "arm32v6" ] && wget --quiet -O /tmp/traefik.tgz "https://github.com/containous/traefik/releases/download/v$VERSION/traefik_v${VERSION}_linux_armv6.tar.gz"; \
    [ "${ARCH}" == "amd64" ] && wget --quiet -O /tmp/traefik.tgz "https://github.com/containous/traefik/releases/download/v$VERSION/traefik_v${VERSION}_linux_amd64.tar.gz"; \
    tar -C /usr/bin -xvf /tmp/traefik.tgz traefik                           && \
    chmod +x /usr/bin/traefik                                               && \
    rm -f /tmp/traefik.tgz

WORKDIR "${CONFIGDIR}"
VOLUME "${CONFIGDIR}"
EXPOSE "${PORT_HTTP}" "${PORT_HTTPS}" "${PORT_API}"
HEALTHCHECK --interval=1m --timeout=3s CMD curl -f http://127.0.0.1:8181/ping || exit 1

ENTRYPOINT ["/run.sh"]

# Define default command
CMD ["traefik"]

