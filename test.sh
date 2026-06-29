#!/usr/bin/env sh
set -e

echo "--- HTTP JSON-RPC: eth_chainId (expect 0x64 = 100, Gnosis) ---"
curl -sS -X POST -H 'Content-Type: application/json' \
	-d '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' \
	http://localhost:8083/
echo

echo "--- HTTP JSON-RPC: eth_blockNumber ---"
curl -sS -X POST -H 'Content-Type: application/json' \
	-d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
	http://localhost:8083/
echo

echo "--- WS: eth_chainId via wscat (needs: npm i -g wscat) ---"
wscat -x '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' -c ws://localhost:8083/
