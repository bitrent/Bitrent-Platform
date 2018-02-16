#!/usr/bin/env bash

docker exec -i ethernode_ethereum-bridge_1 node bridge -H ethernode:8545 -a 0 $@