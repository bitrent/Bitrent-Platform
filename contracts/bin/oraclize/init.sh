#!/usr/bin/env bash

sudo rm -rf ./../../data/ethereum-bridge/config/*
sudo rm -rf ./../../data/ethereum-bridge/database/*
docker exec -i ethernode_ethereum-bridge_1 node bridge -H ethernode:8545 -a 0 $@