const moment    = require('moment');
const abi       = require('ethereumjs-abi');
const Promise   = require('bluebird');
const util      = require('util');
const _         = require('lodash');

const UnityToken        = artifacts.require("./UnityToken.sol");
const PermissionManager = artifacts.require("./PermissionManager.sol");
const Registry          = artifacts.require("./Registry.sol");
const Hold              = artifacts.require("./Hold.sol");
const Crowdsale         = artifacts.require("./Crowdsale.sol");
const Object            = artifacts.require("./Object.sol");
const ConvertQuote      = artifacts.require("./ConvertQuote.sol");

class Migration {
  constructor (deployer, contract, constructorArgs = null, constructorArgsType = [], params = null) {
    this.deployer = deployer;
    this.contract = contract;

    this.args = [];

    this.constructorArgs = constructorArgs;
    this.constructorArgsRaw = constructorArgs;
    this.constructorArgsType = constructorArgsType;
    this.params = params;

    this.name = contract.contractName;
    this.instance = null;
    this.address = null;
    this.abi = contract.abi;
    this.constructorABI = null;

    this.prepeaContractDeploy(constructorArgs, params);
    return this;
  }

  prepeaContractDeploy(args = null, params = null) {
    this.args = [this.contract];
    if(args) {
      if(typeof args === "object") {
        args = this.getConstructor(args);
        this.args = this.args.concat(args);
      } else {
        this.args.push(args);
        args = [args];
      }
    }
    if(this.params || params) {
      params = _.assign({}, this.params, params);
    }
    if(params) {
      this.args.push(params);
      this.params = params;
    }
    this.constructorArgs = args;
    this.constructorABI = abi.rawEncode(this.constructorArgsType, args).toString('hex');
  }

  deploy(args = null, params = null) {
    if(args || params) {
      if(typeof args === "object" && this.constructorArgsRaw && typeof this.constructorArgsRaw === "object") {
        args = _.assign({},this.constructorArgsRaw, args);
        this.constructorArgsRaw = args;
      }
      this.prepeaContractDeploy(args, params);
    }
    return new Promise((resolve, reject) => {
      return this.deployer.deploy.apply(this.deployer,this.args)
        .then(() => this.contract.deployed())
        .then((instance) => {
          if(instance) {
            this.address = this.contract.address;
            this.instance = instance;
            resolve(true);
          } else {
            reject({
              contract: this.name,
              message:`------ ERROR instance [${this.name}]------`
            });
          }
        })
        .catch((e) => {
          reject({
            contract: this.name,
            message:`------ ERROR [${this.name}]------`,
            error:e
          });
        });
    });
  }

  getInfo(print = true) {
    if(print) {
      console.log(`\n${this.name} :`);
      console.log('Address:       ', this.address);
      console.log('ContractABI:\n');
      console.log(this.constructorABI);
      console.log('\nABI:\n');
      console.log(JSON.stringify(this.abi));
      console.log('\n\n\n');
    } else {
      return {
        name: this.name,
        address: this.address,
        constructorAbi:JSON.stringify(this.abi),
        abi: this.abi,
      }
    }
  }

  getName() {
    return this.name
  }
  getAddress() {
    return this.address
  }

  getConstructor(args = {}) {
    let array = [];
    for(let i in args){
      array.push(args[i]);
    }
    return array;
  }
}

module.exports = function(deployer, network) {

  /* base */
  let multisigAddress = '0xB34dCD26b0181329DdA3f81F5B44A6397B02A719'; // type address Multisig
  let managerAddress = '0xaA92aD80969519b9061f4b73CcaEc340182271Bc'; // type address AssetsPreSaleOwner call AddToWhitelist
  let OAR = null;
  let crowdsaleEnd = 120;

  if(network === "development") {
    multisigAddress = '0x220cd6ebb62f9ad170c9bf7984f22a3afc023e7d';
    managerAddress = '0x4dc884abb17d11de6102fc1ef2cee0ebd31df248';
    OAR = '0x6f485c8bf6fc43ea212e93bbf8ce046c7f1cb475';

  } else {
    multisigAddress = '0x220cd6ebb62f9ad170c9bf7984f22a3afc023e7d';
    managerAddress = '0x4dc884abb17d11de6102fc1ef2cee0ebd31df248';
    crowdsaleEnd = 2880; // 2 day
  }

  /* UnityToken.sol */
  let UnityTokenInstance        = new Migration(deployer, UnityToken);

  /* PermissionManager.sol */
  let PermissionManagerInstance = new Migration(deployer, PermissionManager);

  /* Registry.sol */
  let RegistryInstance          = new Migration(deployer, Registry, '0x0', ['address']);

  /* Hold.sol */
  let HoldArgsType = ['address', 'uint', 'address', 'address', 'address'];
  let HoldArgs = {
    _multisig: multisigAddress, //address
    cap: 0, //uint
    pm: '0x0', //address
    registryAddress: '0x0', // address
    observerAddr: '0x0' //address
  };
  let HoldInstance  = new Migration(deployer, Hold, HoldArgs, HoldArgsType);

  /* Crowdsale.sol */
  let CrowdsaleArgsType = ['address', 'address', 'address', 'uint', 'uint', 'uint', 'uint', 'address', 'uint'];
  let CrowdsaleArgs = {
    tokenAddress       : '0x0',
    registryAddress    : '0x0',
    _permissionManager : '0x0',
    start              :  moment().unix(),
    end                :  moment().add(crowdsaleEnd, 'minute').unix(),
    _softCap           : '1335000000',
    _hardCap           : '4450000000',
    holdCont           : '0x0',
    _ethUsdPrice       : '85000'
  };
  let CrowdsaleInstance = new Migration(deployer, Crowdsale, CrowdsaleArgs, CrowdsaleArgsType);

  /* Object.sol */

  let ObjectArgsType = [
    'string' , 'uint32' , 'uint32' , 'uint32' , 'uint',
    'string' , 'string' , 'string' , 'uint' , 'uint' , 'uint' ,
    'address' , 'address' , 'address' , 'address' , 'address'
  ];
  let ObjectArgs = {
    iName       : 'UNITY TOWERS',
    iGBA        : 100000,
    iGSA        : 65000,
    iParking    : 450,
    iUnit       : 1,
    iDeveloper  : 'MegaLINE',
    iLeed       : 'Pass',
    iLocation   : 'Ukraine, Odessa, Gagarin Plato str., 5/1',
    iStartDate  : 1522368000,
    iEndDate    : 1590796800,
    UNTSQM      : '263000000000000000', // 0,263
    iToken      : '0x0',
    iCrowdsale  : '0x0',
    iObserver   : '0x0',
    iHold       : '0x0',
    pManager    : '0x0'
  };
  let ObjectInstance = new Migration(deployer, Object, ObjectArgs, ObjectArgsType);

  /* ConvertQuote.sol */
  let ConvertQuoteInstance = new Migration(deployer, ConvertQuote, 89000, ['uint'], { value: 1000000000000000000 });


  return UnityTokenInstance.deploy()
    .then(() => PermissionManagerInstance.deploy())
    .then(() => RegistryInstance.deploy(PermissionManagerInstance.address))
    .then(() => HoldInstance.deploy({ registryAddress: RegistryInstance.address, pm: PermissionManagerInstance.address }))
    .then(() => {
      let args = {
        tokenAddress        : UnityTokenInstance.address,
        registryAddress     : RegistryInstance.address,
        holdCont            : HoldInstance.address,
        _permissionManager  : PermissionManagerInstance.address
      };
      return CrowdsaleInstance.deploy(args);
    })
    .then(() => {
      let args = {
        iToken      : UnityTokenInstance.address,
        iCrowdsale  : CrowdsaleInstance.address,
        iHold       : HoldInstance.address,
        pManager    : PermissionManagerInstance.address
      };
      return ObjectInstance.deploy(args);
    })
    .then(() => ConvertQuoteInstance.deploy())
    .then(() => {

      console.log('\n\n\nDeployInfo\n');
      console.log('tokenAddress:        ', UnityTokenInstance.address);
      console.log('multisigAddress:     ', multisigAddress);
      console.log('managerAddress:      ', managerAddress);
      console.log('PermissionManager:   ', PermissionManagerInstance.address);
      console.log('Registry:            ', RegistryInstance.address);
      console.log('Hold:                ', HoldInstance.address);
      console.log('Crowdsale:           ', CrowdsaleInstance.address);
      console.log('Object:              ', ObjectInstance.address);
      console.log('ConvertQuote:        ', ConvertQuoteInstance.address);

      UnityTokenInstance.getInfo();
      PermissionManagerInstance.getInfo();
      RegistryInstance.getInfo();
      HoldInstance.getInfo();
      CrowdsaleInstance.getInfo();
      ObjectInstance.getInfo();
      ConvertQuoteInstance.getInfo();

      return true;
    })
    .then(() => {
      return Promise.all([
        OAR ? ConvertQuoteInstance.instance.setOraclizeAddrResolverI(OAR) : Promise.resolve(true),
        ConvertQuoteInstance.instance.setWatcher(CrowdsaleInstance.address),
        CrowdsaleInstance.instance.setStatusI(ObjectInstance.address),
        CrowdsaleInstance.instance.setEthPriceProvider(ConvertQuoteInstance.address),
        PermissionManagerInstance.instance.addAddress(managerAddress),
        PermissionManagerInstance.instance.addAddress(CrowdsaleInstance.address)
      ])
        .then((data) => {
          console.log('\nRun contract method [1]:\n');
          OAR && console.log(`ConvertQuoteInstance->setOraclizeAddrResolverI(${OAR})\n`);
          console.log(`ConvertQuoteInstance->setWatcher(${CrowdsaleInstance.address})\n`);
          console.log(`CrowdsaleInstance->setEthPriceProvider(${ConvertQuoteInstance.address})\n`);
          console.log(`CrowdsaleInstance->setStatusI(${ObjectInstance.address})\n`);
          console.log(`PermissionManagerInstance->addAddress(${managerAddress})\n`);
          console.log(`PermissionManagerInstance->addAddress(${CrowdsaleInstance.address})\n`);

        })
    })
    .then(() => {
      return Promise.all([
        ConvertQuoteInstance.instance.startUpdate(85000, { value: 1000000000000000000 }),
        CrowdsaleInstance.instance.startCrowdsale(),
      ])
        .then(() => {
          console.log('\nRun contract method [2]:\n');
          console.log(`ConvertQuoteInstance->startUpdate(85000,1 eth)\n`);
          console.log(`CrowdsaleInstance->startCrowdsale()\n`);
          return Promise.resolve(true);
        })
    })
    .catch(e => {
      console.log('------ Migration Error ------\n');
      console.error(e);
    });

};
