This allows to configure several upstreams in `PROXY_TO`. The load balancing is configured such, that the first
mentioned upstream is used first until it fails. The failover upstreams will be used until at least 30s after the
failure of the first. 

In case of websocket connections, this means that:

- if main upstream goes down, the consumer will lose connection
- second connection attempt will fail
- third connection attempt will connect secondary upstream
- it will stay with the secondary until the connection is closed AND at least 30sec have passed since the failed second connection attempt


To test / reproduce:

```
docker compose up
wscat --connect localhost:8083
# connected to echo1
docker compose stop echo1
# kills connection
wscat --connect localhost:8083
# fails
wscat --connect localhost:8083
# succeeds to echo2
^d
# disconnects
sleep 30 && docker compose start echo1
wscat --connect localhost:8083
# recconnects to echo1 (without sleep, it may only reconnect to echo2)
