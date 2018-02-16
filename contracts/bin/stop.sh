#!/usr/bin/env bash

confirm() {
  read -r -p "${1:-You will stop EtherNode container. Are you sure? [y/N]} " response
  case "$response" in
    [yY][eE][sS]|[yY])
      true
      ;;
    *)
      false
      ;;
  esac
}

confirm && cd .. && docker container stop ethernode_ethernode_1 && docker container stop ethernode_truffle_1 && docker-compose -p ethernode stop
