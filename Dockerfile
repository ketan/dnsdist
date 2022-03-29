FROM alpine AS builder

ARG DNSDIST_VERSION=1.7.0

RUN apk --update upgrade && \
    apk add ca-certificates curl jq && \
    apk add --virtual .build-depends \
      file gnupg g++ make \
      boost-dev openssl-dev libsodium-dev lua-dev net-snmp-dev protobuf-dev h2o-dev \
      libedit-dev re2-dev && \
    [ -n "$DNSDIST_VERSION" ] || { curl -sSL 'https://api.github.com/repos/PowerDNS/pdns/tags?per_page=100&page={1,2,3}' | jq -rs '[.[][]]|map(select(has("name")))|map(select(.name|contains("dnsdist-")))|map(.version=(.name|ltrimstr("dnsdist-")))|map(select(true != (.version|contains("-"))))|map(.version)|"DNSDIST_VERSION="+.[0]' > /tmp/latest-dnsdist-tag.sh && . /tmp/latest-dnsdist-tag.sh; } && \
    mkdir -v -m 0700 -p /root/.gnupg && \
    curl -RL -O 'https://dnsdist.org/_static/dnsdist-keyblock.asc' && \
    gpg2 --no-options --verbose --keyid-format 0xlong --keyserver-options auto-key-retrieve=true \
        --import *.asc && \
    curl -RL -O "https://downloads.powerdns.com/releases/dnsdist-${DNSDIST_VERSION}.tar.bz2{.asc,.sig,}" && \
    gpg2 --no-options --verbose --keyid-format 0xlong --keyserver-options auto-key-retrieve=true \
        --verify *.sig && \
    rm -rf /root/.gnupg *.asc *.sig && \
    tar -xpf "dnsdist-${DNSDIST_VERSION}.tar.bz2" && \
    rm -f "dnsdist-${DNSDIST_VERSION}.tar.bz2" && \
    ( \
        cd "dnsdist-${DNSDIST_VERSION}" && \
        ./configure --sysconfdir=/etc/dnsdist --mandir=/usr/share/man \
            --enable-dns-over-https \
            --enable-dnscrypt --enable-dns-over-tls --with-libsodium --with-re2 --with-net-snmp && \
        make -j 3 && \
        make install-strip \
    ) && \
    apk del --purge .build-depends && rm -rf /var/cache/apk/*

FROM alpine

RUN apk --update upgrade && \
    apk add ca-certificates curl less mdocml \
        openssl libsodium lua net-snmp protobuf h2o \
        libedit re2 && \
    rm -rf /var/cache/apk/*

COPY --from=builder /usr/local/bin /usr/local/bin/

RUN /usr/local/bin/dnsdist --version

ENTRYPOINT ["/usr/local/bin/dnsdist"]
CMD ["--help"]
