#!/usr/bin/env sh

_PROXY_TO=$(echo $PROXY_TO | awk '{gsub(/,/, " "); print; exit}')
export _PROXY_TO
exec caddy run --config /etc/caddy/Caddyfile
