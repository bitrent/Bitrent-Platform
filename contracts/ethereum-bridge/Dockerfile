FROM node:latest

RUN apt-get update && \
    apt-get -y -qq upgrade && \
    apt-get -y -qq install build-essential && \
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN mkdir -p /usr/src/app

WORKDIR /usr/src/app

RUN git clone https://github.com/Mobelis/ethereum-bridge.git

WORKDIR /usr/src/app/ethereum-bridge

RUN npm i