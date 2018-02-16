#!/usr/bin/env bash

cd ..
docker-compose -p ethernode -f docker-compose.yml -f docker-compose.rinkeby.yml up $@