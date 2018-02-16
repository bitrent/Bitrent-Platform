pragma solidity ^0.4.18;

contract EventI {

  event Log (address whoCalled, string eventName, address contributor);
  event Log (address whoCalled, string eventName, address contributor, uint[] data);
  event Log (address whoCalled, string eventName, address contributor, uint data);
  event Log (address whoCalled, string eventName, address contributor, string data);

  function receiveEvent(address whoCalled, string eventName, address contributor) external {
    Log(whoCalled,eventName,contributor);
  }
  function receiveEvent(address whoCalled, string eventName, address contributor, uint[] data) external {
    Log(whoCalled,eventName,contributor,data);
  }
  function receiveEvent(address whoCalled, string eventName, address contributor, uint data) external {
    Log(whoCalled,eventName,contributor,data);
  }
  function receiveEvent(address whoCalled, string eventName, address contributor, string data) external {
    Log(whoCalled,eventName,contributor,data);
  }
}
