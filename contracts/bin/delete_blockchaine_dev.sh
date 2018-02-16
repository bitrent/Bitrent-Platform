#!/usr/bin/env bash

if [ "$(docker ps -q -f name=ethernode_ethernode_1)" ]; then
  #if container running
  docker exec -ti ethernode_ethernode_1 rm -rf /root/.ethereum/devnet/geth && docker container restart ethernode_ethernode_1
else
  sudo rm -rf ../data/ethernode/.ethereum/devnet/geth
  echo "rm ../data/ethernode/.ethereum/devnet/geth";
fi