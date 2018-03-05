pragma solidity ^0.4.18;
import './base/OraclizeC.sol';
/**
 * @author Emil Dudnyk
 */
contract Stage is OraclizeC {

  bool public status = false;
  address public observer;

  event Start(bool status, uint blockTimestamp);
  event Stop(bool status, uint blockTimestamp);
  event QueryResult(bool result, uint blockTimestamp);

  modifier onlyObserver() {
    require(msg.sender == observer || msg.sender == owner);
    _;
  }

  function Stage(address _observer, string _url) payable public {
    require(_observer != 0x0);
    observer = _observer;
    updateInterval = 1*day;
    url = _url;
  }

  function setObserver(address _observer) public onlyOwner {
    require(_observer != 0x0);
    observer = _observer;
  }

  function start() public onlyObserver returns(bool) {
    require(status == false);
    state = State.Active;
    update(updateInterval);
    Start(status, now);
    return true;
  }

  function stop() public onlyObserver returns(bool) {
    state = State.Stopped;
    Stop(status, now);
    return true;
  }

  function getStatus() public view returns(bool) {
    return status;
  }

  function __callback(bytes32 myid, string result) public {
    require(msg.sender == oraclize_cbAddress() && validIds[myid]);
    delete validIds[myid];

    bool newResult = (keccak256(result) == keccak256("true"));
    QueryResult(newResult, now);

    if(newResult) {
      status = true;
      state = State.Stopped;
      Stop(status, now);
    }

    if (state == State.Active && status == false) {
      update(updateInterval);
    }

  }

  function update(uint delay) private {
    if (oraclize_getPrice("URL") > this.balance) {
      //stop if we don't have enough funds anymore
      state = State.Stopped;
      Stop(status, now);
      LogOraclizeQuery("Oraclize query was NOT sent", this.balance,block.timestamp);
    } else {
      bytes32 queryId = oraclize_query(delay, "URL", url, gasLimit);
      validIds[queryId] = true;
    }
  }

}