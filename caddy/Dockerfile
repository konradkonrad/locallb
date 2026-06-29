FROM caddy:2.10.2-builder AS builder

RUN xcaddy build v2.10.2 \
    --with github.com/caddy-dns/cloudflare \
    --with github.com/WeidiDeng/caddy-cloudflare-ip

FROM caddy:2.10.2
COPY --from=builder /usr/bin/caddy /usr/bin/caddy
