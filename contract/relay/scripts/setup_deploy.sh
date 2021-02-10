#!/usr/bin/env bash

set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

echo "[setup] Enter contract deployer private key: "
read -r privkey
if [ -z "$privkey" ]; then echo "no private key provided" && exit 1; fi
echo "[setup] Private Key : $privkey"
echo "[setup] Enter ShardID (0,1,2,3): "
read -r shard
if [ -z "$shard" ]; then echo "no shard provided" && exit 1; fi
echo "[setup] ShardID: $shard"
echo "[setup] Enter Network (testnet, mainnet, localnet): "
read -r network
if [ -z "$network" ]; then echo "no network provided" && exit 1; fi
echo "[setup] network: $network"
echo "PRIVATE_KEY='$privkey'
SHARD=$shard
NETWORK=$network
" > $DIR/../.env
