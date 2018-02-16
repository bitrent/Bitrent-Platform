pragma solidity ^0.4.18;

import './lib/SafeMath.sol';
import './base/Ownable.sol';
import './base/oraclizeAPI.sol';
import './base/ETHPriceWatcher.sol';

contract ETHPriceProvider is Ownable, usingOraclize {
  using SafeMath for uint;

  enum State { Stopped, Active }

  uint public updateInterval = 300; //5 minutes by default

  uint public currentPrice;

  uint public gasLimit = 200000; // Oraclize Gas Limit

  string public url;

  mapping (bytes32 => bool) validIds;

  ETHPriceWatcher public watcher;

  State public state = State.Stopped;

  event LogPriceUpdated(string getPrice, uint setPrice, uint blockTimestamp);
  event LogOraclizeQuery(string description, uint balance, uint blockTimestamp);
  event LogStartUpdate(uint startingPrice, uint updateInterval, uint blockTimestamp);
  event LogOraclizeAddrResolverI(address oar);

  function notifyWatcher() internal;

  modifier inActiveState() {
    require(state == State.Active);
    _;
  }

  modifier inStoppedState() {
    require(state == State.Stopped);
    _;
  }

  function ETHPriceProvider(string _url) payable public {
    url = _url;

    //update immediately first time to be sure everything is working - first oraclize request is free.
    update(0);
  }

  //send some funds along with the call to cover oraclize fees
  function startUpdate(uint startingPrice) payable onlyOwner inStoppedState public {
    state = State.Active;

    //we can set starting price manually, contract will notify watcher only in case of allowed diff
    //so owner can't set too small or to big price anyway
    currentPrice = startingPrice;
    update(updateInterval);
    notifyWatcher();
    LogStartUpdate(startingPrice, updateInterval, block.timestamp);
  }

  function stopUpdate() external onlyOwner inActiveState {
    state = State.Stopped;
  }

  function setGasLimit(uint _gasLimit) external onlyOwner {
    require(_gasLimit > 50000);
    gasLimit = _gasLimit;
  }

  function setGasPrice(uint gasPrice) external onlyOwner {
    require(gasPrice >= 1000000000); // 1 Gwei
    oraclize_setCustomGasPrice(gasPrice);
  }

  function setWatcher(address newWatcher) external onlyOwner {
    require(newWatcher != 0x0);
    watcher = ETHPriceWatcher(newWatcher);
  }

  function setUpdateInterval(uint newInterval) external onlyOwner {
    require(newInterval > 0);
    updateInterval = newInterval;
  }

  function setUrl(string newUrl) external onlyOwner {
    require(bytes(newUrl).length > 0);
    url = newUrl;
  }

  function __callback(bytes32 myid, string result) public {
    require(msg.sender == oraclize_cbAddress() && validIds[myid]);
    delete validIds[myid];

    uint newPrice = parseInt(result, 2);

    if (state == State.Active) {
      update(updateInterval);
    }

    require(newPrice > 0);

    currentPrice = newPrice;

    notifyWatcher();
    LogPriceUpdated(result,newPrice,block.timestamp);
  }

  function update(uint delay) private {
    if (oraclize_getPrice("URL") > this.balance) {
      //stop if we don't have enough funds anymore
      state = State.Stopped;
      LogOraclizeQuery("Oraclize query was NOT sent", this.balance,block.timestamp);
    } else {
      bytes32 queryId = oraclize_query(delay, "URL", url, gasLimit);
      validIds[queryId] = true;
    }
  }

  //we need to get back our funds if we don't need this oracle anymore
  function withdraw(address receiver) external onlyOwner inStoppedState {
    require(receiver != 0x0);
    receiver.transfer(this.balance);
  }

  function getQuote() public constant returns (uint) {
    return currentPrice;
  }
  //local development
  function setOraclizeAddrResolverI(address __oar) public onlyOwner {
    require(__oar != 0x0);
    OAR = OraclizeAddrResolverI(__oar);
    LogOraclizeAddrResolverI(__oar);
  }
}

contract ConvertQuote is ETHPriceProvider {
  //Encrypted Query
  function ConvertQuote(uint _currentPrice) ETHPriceProvider("BIa/Nnj1+ipZBrrLIgpTsI6ukQTlTJMd1c0iC7zvxx+nZzq9ODgBSmCLo3Zc0sYZwD8mlruAi5DblQvt2cGsfVeCyqaxu+1lWD325kgN6o0LxrOUW9OQWn2COB3TzcRL51Q+ZLBsT955S1OJbOqsfQ4gg/l2awe2EFVuO3WTprvwKhAa8tjl2iPYU/AJ83TVP9Kpz+ugTJumlz2Y6SPBGMNcvBoRq3MlnrR2h/XdqPbh3S2bxjbSTLwyZzu2DAgVtybPO1oJETY=") payable public {
    currentPrice = _currentPrice;
  }

  function notifyWatcher() internal {
    if(address(watcher) != 0x0) {
      watcher.receiveEthPrice(currentPrice);
    }
  }
}