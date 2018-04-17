pragma solidity ^0.4.21;

contract ERC223Interface {
  uint public totalSupply;
  function balanceOf(address who) public view returns (uint);
  function allowedAddressesOf(address who) public view returns (bool);
  function getTotalSupply() public view returns (uint);

  function transfer(address to, uint value) public returns (bool ok);
  function transfer(address to, uint value, bytes data) public returns (bool ok);
  function transfer(address to, uint value, bytes data, string custom_fallback) public returns (bool ok);

  event Transfer(address indexed from, address indexed to, uint256 value);
}