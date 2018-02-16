#!/usr/bin/env bash

echo 'Start mining'
docker exec -ti ethernode_ethernode_1 geth --exec "if(miner.getHashrate()==0){miner.start(1);console.log('Success')}else{console.log('Mining already started')}" attach ipc:/root/geth_ipc/geth.ipc
