pragma solidity ^0.4.19;

import './lib/SafeMath.sol';
import './base/OraclizeC.sol';
import './base/ETHPriceWatcher.sol';

/**
 * @author Vladimir Kovalchuk
 */
contract ETHPriceProvider is OraclizeC {
  using SafeMath for uint;

  uint public currentPrice;

  ETHPriceWatcher public watcher;

  event LogPriceUpdated(string getPrice, uint setPrice, uint blockTimestamp, bytes32 md);
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
    emit LogStartUpdate(startingPrice, updateInterval, block.timestamp);
  }

  function stopUpdate() external onlyOwner inActiveState {
    state = State.Stopped;
  }

  function setWatcher(address newWatcher) external onlyOwner {
    require(newWatcher != 0x0);
    watcher = ETHPriceWatcher(newWatcher);
  }

  function __callback(bytes32 myid, string result) public   {
    //require(msg.sender == oraclize_cbAddress());
    uint newPrice = parseInt(result, 2);
    currentPrice = newPrice;
    if (state == State.Active) {
      update(updateInterval);
    }
    notifyWatcher();
    emit LogPriceUpdated(result,newPrice,block.timestamp, myid);
  }

  function __callback(bytes32 myid, string result, bytes proof) public   {
    //require(msg.sender == oraclize_cbAddress());
    uint newPrice = parseInt(result, 2);
    currentPrice = newPrice;
    if (state == State.Active) {
      update(updateInterval);
    }
    notifyWatcher();
    emit LogPriceUpdated(result,newPrice,block.timestamp, myid);
    proof;
  }

  function update(uint delay) private {
    if (oraclize_getPrice("URL") > address(this).balance) {
      //stop if we don't have enough funds anymore
      state = State.Stopped;
      emit LogOraclizeQuery("Oraclize query was NOT sent", address(this).balance,block.timestamp);
    } else {
     oraclize_query(delay, "URL", url, gasLimit);

    }
  }

  function getQuote() public constant returns (uint) {
    return currentPrice;
  }

}

contract ConvertQuote is ETHPriceProvider {
  //Encrypted Query
  function ConvertQuote(uint _currentPrice) ETHPriceProvider("json(https://api.kraken.com/0/public/Ticker?pair=ETHUSD).result.XETHZUSD.c.0") payable public {
    currentPrice = _currentPrice;
  }

  function notifyWatcher() internal {
    if(address(watcher) != 0x0) {
      watcher.receiveEthPrice(currentPrice);
    }
  }
}