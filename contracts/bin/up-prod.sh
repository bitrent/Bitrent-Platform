#!/usr/bin/env bash

cd ../..
docker-compose -p ethernode -f docker-compose.yml -f docker-compose.prod.yml up $@
