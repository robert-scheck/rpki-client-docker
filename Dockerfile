#
# Copyright (c) 2020-2022 Robert Scheck <robert@fedoraproject.org>
#
# Permission to use, copy, modify, and distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
#

FROM alpine:latest

LABEL maintainer="Robert Scheck <https://github.com/rpki-client/rpki-client-container>" \
      description="OpenBSD RPKI validator to support BGP Origin Validation" \
      org.opencontainers.image.title="rpki-client" \
      org.opencontainers.image.description="OpenBSD RPKI validator to support BGP Origin Validation" \
      org.opencontainers.image.url="https://www.rpki-client.org/" \
      org.opencontainers.image.documentation="https://man.openbsd.org/rpki-client" \
      org.opencontainers.image.source="https://github.com/rpki-client" \
      org.opencontainers.image.licenses="ISC" \
      org.label-schema.schema-version="1.0" \
      org.label-schema.name="rpki-client" \
      org.label-schema.description="OpenBSD RPKI validator to support BGP Origin Validation" \
      org.label-schema.url="https://www.rpki-client.org/" \
      org.label-schema.usage="https://man.openbsd.org/rpki-client" \
      org.label-schema.vcs-url="https://github.com/rpki-client"

ARG VERSION=8.0
ARG PORTABLE_GIT
ARG PORTABLE_COMMIT
ARG OPENBSD_GIT
ARG OPENBSD_COMMIT

COPY rpki-client.pub entrypoint.sh healthcheck.sh /
RUN set -x && \
  chmod +x /entrypoint.sh /healthcheck.sh

RUN set -x && \
  export BUILDREQ="git autoconf automake libtool signify build-base fts-dev openssl-dev libretls-dev expat-dev" && \
  apk --no-cache upgrade && \
  apk --no-cache add ${BUILDREQ} fts openssl libretls expat rsync tzdata tini && \
  cd /tmp && \
  if [ -z "${PORTABLE_GIT}" -a -z "${PORTABLE_COMMIT}" -a -z "${OPENBSD_GIT}" -a -z "${OPENBSD_COMMIT}" ]; then \
    wget https://ftp.openbsd.org/pub/OpenBSD/rpki-client/rpki-client-${VERSION}.tar.gz && \
    wget https://ftp.openbsd.org/pub/OpenBSD/rpki-client/SHA256.sig && \
    signify -C -p /rpki-client.pub -x SHA256.sig rpki-client-${VERSION}.tar.gz && \
    tar xfz rpki-client-${VERSION}.tar.gz && \
    rm -f rpki-client-${VERSION}.tar.gz && \
    wget https://github.com/rpki-client/rpki-client-openbsd/commit/310baa7d9041619ee76d22941211cbdac7f061af.patch -O - | sed -e '18,23d' | tee /dev/stderr | patch -p4 -d rpki-client-${VERSION}/src && \
    cd rpki-client-${VERSION}; \
  else \
    git clone ${PORTABLE_GIT:-https://github.com/rpki-client/rpki-client-portable.git} && \
    cd rpki-client-portable && \
    git checkout ${PORTABLE_COMMIT:-master} && \
    git clone ${OPENBSD_GIT:-https://github.com/rpki-client/rpki-client-openbsd.git} openbsd && \
    cd openbsd && \
    git checkout ${OPENBSD_COMMIT:-master} && \
    rm -rf .git && \
    cd .. && \
    ./autogen.sh; \
  fi && \
  ./configure \
    --prefix=/usr \
    --with-user=rpki-client \
    --with-tal-dir=/etc/tals \
    --with-base-dir=/var/cache/rpki-client \
    --with-output-dir=/var/lib/rpki-client && \
  make V=1 && \
  addgroup \
    -g 101 \
    -S \
    rpki-client && \
  adduser \
    -h /var/lib/rpki-client \
    -g "OpenBSD RPKI validator" \
    -G rpki-client \
    -S \
    -D \
    -u 100 \
    rpki-client && \
  make install-strip INSTALL='install -p' && \
  cd .. && \
  rm -rf ${OLDPWD} /rpki-client.pub SHA256.sig && \
  apk --no-cache del ${BUILDREQ} && \
  rpki-client -V

ENV TZ=UTC
VOLUME ["/etc/tals/", "/var/cache/rpki-client/", "/var/lib/rpki-client/"]

ENTRYPOINT ["/sbin/tini", "-g", "--", "/entrypoint.sh"]
CMD ["rpki-client", "-B", "-c", "-j", "-o", "-v"]
HEALTHCHECK CMD ["/healthcheck.sh"]
