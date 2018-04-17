pragma solidity ^0.4.21;

import './Ownable.sol';

/*
 * Manager that stores permitted addresses 
 */
contract PermissionManager is Ownable {
    mapping (address => bool) permittedAddresses;

    function addAddress(address newAddress) public onlyOwner {
        permittedAddresses[newAddress] = true;
    }

    function removeAddress(address remAddress) public onlyOwner {
        permittedAddresses[remAddress] = false;
    }

    function isPermitted(address pAddress) public view returns(bool) {
        if (permittedAddresses[pAddress]) {
            return true;
        }
        return false;
    }
}