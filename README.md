# locallb

Caddy-based local proxy that fronts a pool of free, public **Gnosis Chain
mainnet** RPC endpoints (chain ID 100). To clients it looks like one plain
`http://` / `ws://` endpoint on `localhost:8083`; under the hood Caddy fans
out to several public providers and fails over when one starts returning
usage / quota errors.

## Upstreams

WebSocket pool (HTTPS+WSS on the same URL):

- `gnosis-rpc.publicnode.com`
- `gnosis.drpc.org`

HTTP JSON-RPC pool (adds HTTPS-only providers):

- `gnosis-rpc.publicnode.com`
- `gnosis.drpc.org`
- `rpc.gnosischain.com`
- `rpc.gnosis.gateway.fm`
- `1rpc.io/gnosis`

`lb_policy first` means the top entry is always preferred. Lower entries
only see traffic while higher ones are marked unhealthy.

## Failover triggers

An upstream is taken out of rotation for `fail_duration` (30s) after one
failure that matches any of:

- HTTP `403` (forbidden / quota exhausted)
- HTTP `5xx` (upstream error / outage)
- TCP dial error or TLS handshake failure
- Response latency above `unhealthy_latency` (10s)

The same conditions also drive `lb_retry_match`, so a single client request
that lands on a failing upstream is transparently retried against the next
one (up to `lb_retries` 3, within `lb_try_duration` 15s).

HTTP `429` is intentionally **not** in the list. Add `status 429` to both
`unhealthy_status` and the `lb_retry_match` block if you want it.

## TLS termination

The client connects in plaintext (`http://` or `ws://`) to Caddy. Caddy
opens a TLS connection (HTTPS or WSS) to whichever upstream it picks, with
`Host` and SNI both set to the upstream hostname. That mismatch (`Host:
localhost` vs upstream SNI) was the root cause of earlier SSL errors, and
is what the `header_up Host {http.reverse_proxy.upstream.host}` line fixes.

`X-Forwarded-*` headers are stripped so providers see a clean request and
don't rate-limit per original client IP.

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

## Behavior on failover (WebSocket)

WebSocket failover happens at handshake time. Once a stream is established
and the upstream later kills it (mid-stream rate limit, idle disconnect,
node restart), the **client must reconnect**. The reconnect is routed to a
healthy upstream because the failing one is now in the 30s penalty box.

Concretely:

- main upstream goes down → existing WS connection drops on the client
- next connection attempt within `fail_duration` (30s of the failure)
  succeeds against the secondary upstream
- once the primary's 30s penalty expires, new connections prefer it again
