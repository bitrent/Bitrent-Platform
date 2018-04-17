pragma solidity ^0.4.21;
/**
 * @author Emil Dudnyk
 */
contract EventI {

  event Log (address whoCalled, string eventName, address contributor);
  event Log (address whoCalled, string eventName, address contributor, uint[] data);
  event Log (address whoCalled, string eventName, address contributor, uint data);
  event Log (address whoCalled, string eventName, address contributor, string data);

  function receiveEvent(address whoCalled, string eventName, address contributor) external {
    emit Log(whoCalled,eventName,contributor);
  }
  function receiveEvent(address whoCalled, string eventName, address contributor, uint[] data) external {
    emit Log(whoCalled,eventName,contributor,data);
  }
  function receiveEvent(address whoCalled, string eventName, address contributor, uint data) external {
    emit Log(whoCalled,eventName,contributor,data);
  }
  function receiveEvent(address whoCalled, string eventName, address contributor, string data) external {
    emit Log(whoCalled,eventName,contributor,data);
  }
}
