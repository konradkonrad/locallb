#!/usr/bin/env sh

wscat -x test1 -c ws://localhost:8083

docker compose stop echo1

wscat -x test2 -c ws://localhost:8083

wscat -x test3 -c ws://localhost:8083

docker compose start echo1

wscat -x test4 -c ws://localhost:8083

sleep 30

wscat -x test5 -c ws://localhost:8083
