pragma solidity ^0.4.19;
import './Ownable.sol';
import './oraclizeAPI.sol';

/**
 * @author Emil Dudnyk
 */
contract OraclizeC is Ownable, usingOraclize {
  uint public updateInterval = 300; //5 minutes by default
  uint public gasLimit = 200000; // Oraclize Gas Limit
  mapping (bytes32 => bool) validIds;
  string public url;

  enum State { New, Stopped, Active }

  State public state = State.New;

  event LogOraclizeQuery(string description, uint balance, uint blockTimestamp);
  event LogOraclizeAddrResolverI(address oar);

  modifier inActiveState() {
    require(state == State.Active);
    _;
  }

  modifier inStoppedState() {
    require(state == State.Stopped);
    _;
  }

  modifier inNewState() {
    require(state == State.New);
    _;
  }

  function setUpdateInterval(uint newInterval) external onlyOwner {
    require(newInterval > 0);
    updateInterval = newInterval;
  }

  function setUrl(string newUrl) external onlyOwner {
    require(bytes(newUrl).length > 0);
    url = newUrl;
  }

  function setGasLimit(uint _gasLimit) external onlyOwner {
    require(_gasLimit > 50000);
    gasLimit = _gasLimit;
  }

  function setGasPrice(uint gasPrice) external onlyOwner {
    require(gasPrice >= 1000000000); // 1 Gwei
    oraclize_setCustomGasPrice(gasPrice);
  }

  //local development
  function setOraclizeAddrResolverI(address __oar) public onlyOwner {
    require(__oar != 0x0);
    OAR = OraclizeAddrResolverI(__oar);
    emit LogOraclizeAddrResolverI(__oar);
  }

  //we need to get back our funds if we don't need this oracle anymore
  function withdraw(address receiver) external onlyOwner inStoppedState {
    require(receiver != 0x0);
    receiver.transfer(address(this).balance);
  }
}