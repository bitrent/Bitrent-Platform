/**
 * @author Emil Dudnyk
 */
const moment    = require('moment');
const abi       = require('ethereumjs-abi');
const Promise   = require('bluebird');
const util      = require('util');
const _         = require('lodash');
const fetch     = require('node-fetch');
const fs        = require('fs');

const UnityToken        = artifacts.require("./UnityToken.sol");
const PermissionManager = artifacts.require("./PermissionManager.sol");
const Registry          = artifacts.require("./Registry.sol");
const Hold              = artifacts.require("./Hold.sol");
const Crowdsale         = artifacts.require("./Crowdsale.sol");
const Object            = artifacts.require("./Object.sol");
const ConvertQuote      = artifacts.require("./ConvertQuote.sol");
const Observer          = artifacts.require("./Observer.sol");
const Stage             = artifacts.require("./Stage.sol");

class Migration {
  constructor (deployer, contract, constructorArgs = null, constructorArgsType = [], params = null, contractName = null) {
    this.deployer = deployer;
    this.contract = contract;

    this.args = [];
    this.argsConstructor = [];

    this.constructorArgs = constructorArgs;
    this.constructorArgsRaw = constructorArgs;
    this.constructorArgsType = constructorArgsType;
    this.params = params;

    this.name = contractName ? contractName : contract.contractName;
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
        this.argsConstructor = args;
        this.args = this.args.concat(args);
      } else {
        this.args.push(args);
        this.argsConstructor = args;
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
      } else {
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
    //let log = `\n${this.name} :\nAddress:       ${this.address}\nconstructor(${this.constructorArgsRaw?this.constructorArgsRaw.join():''})\n\nContractABI:\n${this.constructorABI}\nABI:\n${JSON.stringify(this.abi)}\n\n\n`;
    let log = `
    ${this.name} :
    Address:       ${this.address}
    constructor: 
    ${this.getConstructorRemix()}
    
    addToWallet:
    ${this.getAddToWallet()}
    
    ContractABI:
    ${this.constructorABI}
    
    ABI:
    ${JSON.stringify(this.abi)}
    \n\n
    `;
    fs.appendFileSync('/usr/src/app/deploy.log', log);
    if(print) {
      console.log(log);
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

  getAddToWallet() {
    return `CustomContracts.upsert({address: "${this.address}"}, { $set: { address: "${this.address}", name: "${this.name}", jsonInterface: ${JSON.stringify(this.abi)} }});`
  }

  getConstructor(args = {}) {
    let array = [];
    for(let i in args){
      array.push(args[i]);
    }
    return array;
  }
  getConstructorRemix() {
    let ret = '()';

    let tmpArgs = null;
    // if(this.constructorArgsRaw && typeof this.constructorArgsRaw === "object") {
    //   tmpArgs = this.getConstructor(this.constructorArgsRaw);
    // } else if(this.constructorArgsRaw && Array.isArray(this.constructorArgsRaw)) {
    //   tmpArgs = this.constructorArgsRaw;
    // } else if(this.constructorArgsRaw && typeof this.constructorArgsRaw === "string") {
    //   tmpArgs = [this.constructorArgsRaw]
    // }
    if(this.argsConstructor && Array.isArray(this.argsConstructor)) {
      tmpArgs = this.argsConstructor;
    } else if(this.argsConstructor && typeof this.argsConstructor === "string") {
      tmpArgs = [this.argsConstructor]
    }
    if(tmpArgs) {
      ret = `("${tmpArgs.join('","')}")`;
    }

    return ret;
  }

  static clearLog() {
    let file = '/usr/src/app/deploy.log';
    if (fs.existsSync(file)) {
      fs.truncateSync(file);
    } else {
      fs.closeSync(fs.openSync(file, 'w'));
    }
  }
}

function log(str,str1 = '') {
  console.log(str,str1);
  fs.appendFileSync('/usr/src/app/deploy.log', str+str1+'\n');
}
function logToFile(str, str1 = '') {
  fs.appendFileSync('/usr/src/app/deploy.log', str+str1+'\n');
}

module.exports = function(deployer, network) {
  Migration.clearLog();

  /* base */
  let multisigAddress = '0xB34dCD26b0181329DdA3f81F5B44A6397B02A719'; // type address Multisig
  let managerAddress = '0xaA92aD80969519b9061f4b73CcaEc340182271Bc'; // type address AssetsPreSaleOwner call AddToWhitelist
  let OAR = null;
  let crowdsaleEnd = 120;
  //http://api.bitrent.uk/api/sensors/
  let sensorsApiUrl = [
    'json(http://api.bitrent.uk/api/sensors/5a86b6c4b3592c003e7a2234).status',
    'json(http://api.bitrent.uk/api/sensors/5a86b6c4b3592c003e7a2235).status',
    'json(http://api.bitrent.uk/api/sensors/5a86b6c4b3592c003e7a2236).status',
    'json(http://api.bitrent.uk/api/sensors/5a86b6c4b3592c003e7a2237).status',
    'json(http://api.bitrent.uk/api/sensors/5a86b6c4b3592c003e7a2238).status',
  ];

  if(network === "development") {
    multisigAddress = '0x220cd6ebb62f9ad170c9bf7984f22a3afc023e7d';
    managerAddress = '0x4dc884abb17d11de6102fc1ef2cee0ebd31df248';
    OAR = '0x6f485c8bf6fc43ea212e93bbf8ce046c7f1cb475';

  } else {
    multisigAddress = '0x220cd6ebb62f9ad170c9bf7984f22a3afc023e7d';
    managerAddress = '0x4dc884abb17d11de6102fc1ef2cee0ebd31df248';
    crowdsaleEnd = 2880; // 2 day
  }

  let ethPrice = 85200;

  /* UnityToken.sol */
  let UnityTokenInstance        = new Migration(deployer, UnityToken);

  /* PermissionManager.sol */
  let PermissionManagerInstance = new Migration(deployer, PermissionManager);

  /* Observer.sol */
  let ObserverInstance = new Migration(deployer, Observer, '0x0', ['address'], { value: 500000000000000000 });

  /* Stage.sol */
  let Stage1Instance = new Migration(deployer, Stage, {_observer: '0x0', _url: sensorsApiUrl[0]}, ['address', 'string'], { value: 300000000000000000 }, 'Stage1');
  let Stage2Instance = new Migration(deployer, Stage, {_observer: '0x0', _url: sensorsApiUrl[1]}, ['address', 'string'], { value: 300000000000000000 }, 'Stage2');
  let Stage3Instance = new Migration(deployer, Stage, {_observer: '0x0', _url: sensorsApiUrl[2]}, ['address', 'string'], { value: 300000000000000000 }, 'Stage3');
  let Stage4Instance = new Migration(deployer, Stage, {_observer: '0x0', _url: sensorsApiUrl[3]}, ['address', 'string'], { value: 300000000000000000 }, 'Stage4');
  let Stage5Instance = new Migration(deployer, Stage, {_observer: '0x0', _url: sensorsApiUrl[4]}, ['address', 'string'], { value: 300000000000000000 }, 'Stage5');

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
    start              :  moment().unix(), //1520683200 03/10/2018 @ 12:00pm (UTC)
    end                :  moment().add(crowdsaleEnd, 'minute').unix(), //1526385600 05/15/2018 @ 12:00pm (UTC)
    _softCap           : '1335000000',//13 350 000 $
    _hardCap           : '4450000000',//44 500 000 $
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
    iUnit       : 1, //appartment
    iDeveloper  : 'MegaLINE',
    iLeed       : 'Pass',
    iLocation   : 'Ukraine, Odessa, Gagarin Plato str., 5/1',
    iStartDate  : 1522368000, // 03/30/2018 @ 12:00am (UTC)
    iEndDate    : 1590796800, // 05/30/2020 @ 12:00am (UTC)
    UNTSQM      : '263000000000000000', // 0,263
    iToken      : '0x0',
    iCrowdsale  : '0x0',
    iObserver   : '0x0',
    iHold       : '0x0',
    pManager    : '0x0'
  };
  let ObjectInstance = new Migration(deployer, Object, ObjectArgs, ObjectArgsType);

  /* ConvertQuote.sol */
  let ConvertQuoteInstance = new Migration(deployer, ConvertQuote, ethPrice, ['uint'], { value: 500000000000000000 });

  return fetch('https://api-rinkeby.etherscan.io/api?module=stats&action=ethprice&apikey=YourApiKeyToken')
    .then(res => ethPrice = _.get(res.json(),'result.ethusd',ethPrice))
    .then(() => UnityTokenInstance.deploy())
    .then(() => PermissionManagerInstance.deploy())
    .then(() => RegistryInstance.deploy(PermissionManagerInstance.address))
    .then(() => ObserverInstance.deploy(PermissionManagerInstance.address))
    .then(() => Stage1Instance.deploy({ _observer: ObserverInstance.address}))
    .then(() => Stage2Instance.deploy({ _observer: ObserverInstance.address}))
    .then(() => Stage3Instance.deploy({ _observer: ObserverInstance.address}))
    .then(() => Stage4Instance.deploy({ _observer: ObserverInstance.address}))
    .then(() => Stage5Instance.deploy({ _observer: ObserverInstance.address}))
    .then(() => HoldInstance.deploy({ registryAddress: RegistryInstance.address, pm: PermissionManagerInstance.address, observerAddr: ObserverInstance.address }))
    .then(() => {
      let args = {
        tokenAddress        : UnityTokenInstance.address,
        registryAddress     : RegistryInstance.address,
        holdCont            : HoldInstance.address,
        _permissionManager  : PermissionManagerInstance.address,
      };
      return CrowdsaleInstance.deploy(args);
    })
    .then(() => {
      let args = {
        iToken      : UnityTokenInstance.address,
        iCrowdsale  : CrowdsaleInstance.address,
        iHold       : HoldInstance.address,
        pManager    : PermissionManagerInstance.address,
        iObserver   : ObserverInstance.address,
      };
      return ObjectInstance.deploy(args);
    })
    .then(() => ConvertQuoteInstance.deploy())
    .then(() => {

      log('\n\n\nDeployInfo');
      log('tokenAddress:        ', UnityTokenInstance.address);
      log('multisigAddress:     ', multisigAddress);
      log('managerAddress:      ', managerAddress);
      log('PermissionManager:   ', PermissionManagerInstance.address);
      log('Observer:            ', ObserverInstance.address);
      log('Stage1:              ', Stage1Instance.address);
      log('Stage2:              ', Stage2Instance.address);
      log('Stage3:              ', Stage3Instance.address);
      log('Stage4:              ', Stage4Instance.address);
      log('Stage5:              ', Stage5Instance.address);
      log('Registry:            ', RegistryInstance.address);
      log('Hold:                ', HoldInstance.address);
      log('Crowdsale:           ', CrowdsaleInstance.address);
      log('Object:              ', ObjectInstance.address);
      log('ConvertQuote:        ', ConvertQuoteInstance.address);

      UnityTokenInstance.getInfo();
      PermissionManagerInstance.getInfo();
      ObserverInstance.getInfo();
      Stage1Instance.getInfo();
      Stage2Instance.getInfo();
      Stage3Instance.getInfo();
      Stage4Instance.getInfo();
      Stage5Instance.getInfo();
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
        OAR ? ObserverInstance.instance.setOraclizeAddrResolverI(OAR) : Promise.resolve(true),
        OAR ? Stage1Instance.instance.setOraclizeAddrResolverI(OAR) : Promise.resolve(true),
        OAR ? Stage2Instance.instance.setOraclizeAddrResolverI(OAR) : Promise.resolve(true),
        OAR ? Stage3Instance.instance.setOraclizeAddrResolverI(OAR) : Promise.resolve(true),
        OAR ? Stage4Instance.instance.setOraclizeAddrResolverI(OAR) : Promise.resolve(true),
        OAR ? Stage5Instance.instance.setOraclizeAddrResolverI(OAR) : Promise.resolve(true),

        ConvertQuoteInstance.instance.setWatcher(CrowdsaleInstance.address),
        CrowdsaleInstance.instance.setStatusI(ObjectInstance.address),
        CrowdsaleInstance.instance.setEthPriceProvider(ConvertQuoteInstance.address),
        PermissionManagerInstance.instance.addAddress(managerAddress),
        PermissionManagerInstance.instance.addAddress(CrowdsaleInstance.address),
        PermissionManagerInstance.instance.addAddress(ObserverInstance.address),
        ObserverInstance.instance.setHold(HoldInstance.address),
        ObserverInstance.instance.setBuildingStatus(ObjectInstance.address),

        ObserverInstance.instance.setStagesContract(1,Stage1Instance.address),
        ObserverInstance.instance.setStagesContract(2,Stage2Instance.address),
        ObserverInstance.instance.setStagesContract(3,Stage3Instance.address),
        ObserverInstance.instance.setStagesContract(4,Stage4Instance.address),
        ObserverInstance.instance.setStagesContract(5,Stage5Instance.address),
        UnityTokenInstance.instance.addAllowed(CrowdsaleInstance.address),
      ])
        .then((data) => {
          log('\nRun contract method [1]:\n');
          OAR && log(`ConvertQuoteInstance->setOraclizeAddrResolverI(${OAR})\n`);
          OAR && log(`ObserverInstance->setOraclizeAddrResolverI(${OAR})\n`);
          OAR && log(`Stage1Instance->setOraclizeAddrResolverI(${OAR})\n`);
          OAR && log(`Stage2Instance->setOraclizeAddrResolverI(${OAR})\n`);
          OAR && log(`Stage3Instance->setOraclizeAddrResolverI(${OAR})\n`);
          OAR && log(`Stage4Instance->setOraclizeAddrResolverI(${OAR})\n`);
          OAR && log(`Stage5Instance->setOraclizeAddrResolverI(${OAR})\n`);

          log(`ConvertQuoteInstance->setWatcher(${CrowdsaleInstance.address})\n`);
          log(`CrowdsaleInstance->setEthPriceProvider(${ConvertQuoteInstance.address})\n`);
          log(`CrowdsaleInstance->setStatusI(${ObjectInstance.address})\n`);
          log(`PermissionManagerInstance->addAddress(${managerAddress})\n`);
          log(`PermissionManagerInstance->addAddress(${CrowdsaleInstance.address})\n`);
          log(`PermissionManagerInstance->addAddress(${ObserverInstance.address})\n`);
          log(`ObserverInstance->setHold(${HoldInstance.address})\n`);
          log(`ObserverInstance->setBuildingStatus(${ObjectInstance.address})\n`);
          log(`UnityTokenInstance->addAllowed(${CrowdsaleInstance.address})\n`);
        })
    })
    .then(() => {
      return Promise.all([
        ConvertQuoteInstance.instance.startUpdate(ethPrice, { gas: 200000, value: 100000000000000000 }),
        CrowdsaleInstance.instance.startCrowdsale({ gas: 100000 }),
        ObserverInstance.instance.start({ gas: 400000 }),
      ])
      .then(() => {
        log('\nRun contract method [2]:\n');
        log(`ConvertQuoteInstance->startUpdate(${ethPrice}, 0.1 eth)\n`);
        log(`CrowdsaleInstance->startCrowdsale()\n`);
        log(`ObserverInstance->start()\n`);

        logToFile(`\n
        Add contract to Ethereum Wallet console:
        
        CustomContracts.find().fetch().map(function(contract) { CustomContracts.remove(contract._id) });
        Tokens.find({symbol:"UNT"}).fetch().map(function(token) {Tokens.remove(token._id)});
        tokenId = Helpers.makeId('token', "${UnityTokenInstance.address}");
        Tokens.upsert(tokenId, {$set: {
            address: "${UnityTokenInstance.address}",
            name: "Unity Token",
            symbol: "UNT",
            balances: {},
            decimals: 18
        }});
        ${UnityTokenInstance.getAddToWallet()}
        ${PermissionManagerInstance.getAddToWallet()}
        ${ObserverInstance.getAddToWallet()}
        ${Stage1Instance.getAddToWallet()}
        ${Stage2Instance.getAddToWallet()}
        ${Stage3Instance.getAddToWallet()}
        ${Stage4Instance.getAddToWallet()}
        ${Stage5Instance.getAddToWallet()}
        ${RegistryInstance.getAddToWallet()}
        ${HoldInstance.getAddToWallet()}
        ${CrowdsaleInstance.getAddToWallet()}
        ${ObjectInstance.getAddToWallet()}
        ${ConvertQuoteInstance.getAddToWallet()}
        `);

        return Promise.resolve(true);
      })
    })
    .catch(e => {
      console.log('------ Migration Error ------\n');
      console.error(e);
    });

};
