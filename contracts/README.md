# Bitrent
```bash
git clone git@gitlab.clever-hosting.com:bitrent-smart-contracts/bitrent-smart-contracts.git
```
- [How to use docker](#how-to-use-docker)

## How to use docker
> To begin with, you need to install a docker CE and a docker-compose according to this instruction 
> [docker CE](https://docs.docker.com/engine/installation/)
> [docker-compose](https://docs.docker.com/compose/install/)

Start private net
```bash
cd bin
./dev-up.sh
```

Start private net truffle migration
```bash
cd bin
./migration-dev.sh
```

Start mining private net
```bash
cd bin
./miner-start.sh
```

Stop mining private net
```bash
cd bin
./miner-stop.sh
```

Start rinkeby net
```bash
cd bin
./rinkeby-up.sh
```

Start rinkeby net truffle migration
> You must create a file with a password in the directory $HOME/ICO/ethernode/rinkeby/password 
> and insert the password from the private key (49b7776ea56080439000fd54c45d72d3ac213020)
```bash
cd bin
./migration-rinkeby.sh
```

Connection Ethereum Wallet to private net:
> Linux
```bash
ethereumwallet --rpc http://localhost:8545
```

Show sync stats:
```bash
cd bin
./sync_stats.sh
```

Start dev net and migration:
```bash
cd bin
./dev-up.sh
./miner-start.sh
./migration-dev.sh
```

If need delete old mining block from dev net
- Set DELETE_OLD_BLOCKCHAIN: 1 from docker-compose.dev.yml and restart docker containers
or use script
```bash
cd bin
./delete_blockchaine.sh
```

Combine all sol file
```bash
cd bin
./combine_contract.sh
```

Oraclize local node 
1. First init after work use Ctr + C on exit
> It is necessary to perform each cleaning of the blockchaine.
> This will generate the address OAR = OraclizeAddrResolverI(0x6f485c8bf6fc43ea212e93bbf8ce046c7f1cb475);
```bash
cd bin
./delete_blockchaine.sh #if need delete old blockchaine
./oraclize/init.sh # first init in clean blockchaine
```
2. Use oraclize after init
```bash
cd bin
./oraclize/start.sh
```

Remove Ethereum Wallet contracts
```javascript
CustomContracts.find().fetch().map(function(contract) { CustomContracts.remove(contract._id) })
```