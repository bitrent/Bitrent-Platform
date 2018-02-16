pragma solidity ^0.4.18;
import './base/PermissionManager.sol';
import './base/Ownable.sol';

contract Observer is Ownable {
  PermissionManager public permissionManager;
  function setPermissionManager(address _permadr) public onlyOwner {
    require(_permadr != 0x0);
    permissionManager = PermissionManager(_permadr);
  }
    
}