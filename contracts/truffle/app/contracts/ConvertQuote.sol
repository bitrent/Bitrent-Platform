pragma solidity ^0.4.18;

import './lib/SafeMath.sol';
import './base/OraclizeC.sol';
import './base/ETHPriceWatcher.sol';
/**
 * @author Emil Dudnyk
 */
contract ETHPriceProvider is OraclizeC {
  using SafeMath for uint;

  uint public currentPrice;

  ETHPriceWatcher public watcher;

  event LogPriceUpdated(string getPrice, uint setPrice, uint blockTimestamp);
  event LogStartUpdate(uint startingPrice, uint updateInterval, uint blockTimestamp);

  function notifyWatcher() internal;

  function ETHPriceProvider(string _url) payable public {
    url = _url;

    //update immediately first time to be sure everything is working - first oraclize request is free.
    //update(0);
  }

  //send some funds along with the call to cover oraclize fees
  function startUpdate(uint startingPrice) payable onlyOwner inNewState public {
    state = State.Active;

    currentPrice = startingPrice;
    update(updateInterval);
    notifyWatcher();
    LogStartUpdate(startingPrice, updateInterval, block.timestamp);
  }

  function stopUpdate() external onlyOwner inActiveState {
    state = State.Stopped;
  }

  function setWatcher(address newWatcher) external onlyOwner {
    require(newWatcher != 0x0);
    watcher = ETHPriceWatcher(newWatcher);
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

  function getQuote() public constant returns (uint) {
    return currentPrice;
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