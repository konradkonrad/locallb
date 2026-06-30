# locallb

Caddy-based local proxy that fronts a pool of free, public **Gnosis Chain
mainnet** RPC endpoints (chain ID 100). To clients it looks like one plain
`http://` / `ws://` endpoint on `localhost:8083`; under the hood Caddy fans
out to several public providers, fails over when one returns a quota or
outage error, and re-tries the same request transparently when possible.

## Upstreams

WebSocket pool (providers that serve both HTTPS and WSS on the same URL):

- `gnosis-rpc.publicnode.com`
- `gnosis.drpc.org`

HTTP JSON-RPC pool:

- `gnosis-rpc.publicnode.com`
- `gnosis.drpc.org`
- `rpc.gnosischain.com`
- `rpc.gnosis.gateway.fm`

`lb_policy first` makes the top entry the preferred one. Lower entries
only see traffic while higher ones are marked unhealthy.

`1rpc.io/gnosis` was considered but Caddy doesn't allow path components in
upstream URLs, so it's not in the pool.

## Failover triggers

An upstream is taken out of rotation for `fail_duration` (30s) after one
match against:

- HTTP `403` (forbidden / quota exhausted)
- HTTP `429` (rate limited)
- HTTP `5xx` (upstream error / outage)
- TCP / TLS dial failure
- Response latency above `unhealthy_latency` (10s)

The same conditions also drive `lb_retry_match` on the HTTP pool, so a
single client request that lands on a failing upstream is retried against
the next one (`lb_retries` 3, `lb_try_duration` 15s). `request_buffers 1MB`
keeps the JSON-RPC body around so the retry has something to send.

### Why WebSockets behave differently

WS failover only happens at handshake time. Once a stream is established
and the upstream later kills it (mid-stream rate limit, idle disconnect,
node restart), the client has to reconnect; the reconnect picks a
different upstream because the failing one is in the 30s penalty box.

WS upgrade requests don't have a body to replay, so `request_buffers`
isn't relevant there.

## TLS termination

The client connects in plaintext (`http://` or `ws://`) to Caddy. Caddy
opens a TLS connection (HTTPS or WSS) to whichever upstream it picks, with
`Host` and SNI both set to the upstream hostname. The
`header_up Host {http.reverse_proxy.upstream.host}` line in the Caddyfile
achieves this.

`X-Forwarded-*` headers are also stripped so providers see a clean
request and don't rate-limit per original client IP.

## Run

```
docker compose up --build
```

Then in another shell:

```
./test.sh
```

Or manually:

```
curl -sS -X POST -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' \
    http://localhost:8083/
# {"jsonrpc":"2.0","id":1,"result":"0x64"}

wscat -c ws://localhost:8083/
> {"jsonrpc":"2.0","method":"eth_subscribe","params":["newHeads"],"id":1}
```

To exercise failover, point the top upstream at a bogus host and watch
the next request still succeed within ~500ms:

```
sed -i.bak 's|gnosis-rpc.publicnode.com|this-host-does-not-exist.example.invalid|' Caddyfile
docker compose restart caddy
curl -sS -X POST -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' \
    http://localhost:8083/
mv Caddyfile.bak Caddyfile
docker compose restart caddy
```
