#!/usr/bin/env bash

docker exec -ti ethernode_ethernode_1 geth --exec "loadScript('/root/sync_stats.js')" attach /root/geth_ipc/geth.ipc
