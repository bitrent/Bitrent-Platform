pragma solidity ^0.4.21;

import './UnityToken.sol';
import './base/Ownable.sol';
import './base/PermissionManager.sol';
import './Registry.sol';

/**
 * @title Hold  contract.
 * @author Vladimir Kovalchuk
 */
contract Hold is Ownable {

    uint8 stages = 5;
    uint8 public percentage;
    uint8 public currentStage;
    uint public initialBalance;
    uint public withdrawed;
    
    address public multisig;
    Registry registry;

    PermissionManager public permissionManager;
    uint nextContributorToTransferEth;
    address public observer;
    uint dateDeployed;
    mapping(address => bool) private hasWithdrawedEth;

    event InitialBalanceChanged(uint balance);
    event EthReleased(uint ethreleased);
    event EthRefunded(address contributor, uint ethrefunded);
    event StageChanged(uint8 newStage);
    event EthReturnedToOwner(address owner, uint balance);

    modifier onlyPermitted() {
        require(permissionManager.isPermitted(msg.sender) || msg.sender == owner);
        _;
    }

    modifier onlyObserver() {
        require(msg.sender == observer || msg.sender == owner);
        _;
    }

    function Hold(address _multisig, uint cap, address pm, address registryAddress, address observerAddr) public {
        percentage = 100 / stages;
        currentStage = 0;
        multisig = _multisig;
        initialBalance = cap;
        dateDeployed = now;
        permissionManager = PermissionManager(pm);
        registry = Registry(registryAddress);
        observer = observerAddr;
    }

    function setPermissionManager(address _permadr) public onlyOwner {
        require(_permadr != 0x0);
        permissionManager = PermissionManager(_permadr);
    }

    function setObserver(address observerAddr) public onlyOwner {
        require(observerAddr != 0x0);
        observer = observerAddr;
    }

    function setInitialBalance(uint inBal) public {
        initialBalance = inBal;
        emit InitialBalanceChanged(inBal);
    }

    function releaseAllETH() onlyPermitted public {
        uint balReleased = getBalanceReleased();
        require(balReleased > 0);
        require(address(this).balance >= balReleased);
        multisig.transfer(balReleased);
        withdrawed += balReleased;
        emit EthReleased(balReleased);
    }

    function releaseETH(uint n) onlyPermitted public {
        require(address(this).balance >= n);
        require(getBalanceReleased() >= n);
        multisig.transfer(n);
        withdrawed += n;
        emit EthReleased(n);
    } 

    function getBalance() public view returns (uint) {
        return address(this).balance;
    }

    function changeStageAndReleaseETH() public onlyObserver {
        uint8 newStage = currentStage + 1;
        require(newStage <= stages);
        currentStage = newStage;
        emit StageChanged(newStage);
        releaseAllETH();
    }

    function changeStage() public onlyObserver {
        uint8 newStage = currentStage + 1;
        require(newStage <= stages);
        currentStage = newStage;
        emit StageChanged(newStage);
    }

    function getBalanceReleased() public view returns (uint) {
        return initialBalance * percentage * currentStage / 100 - withdrawed ;
    }

    function returnETHByOwner() public onlyOwner {
        require(now > dateDeployed + 183 days);
        uint balance = getBalance();
        owner.transfer(getBalance());
        emit EthReturnedToOwner(owner, balance);
    }

    function() public payable {

    }

  function getWithdrawed(address contrib) public onlyPermitted view returns (bool) {
    return hasWithdrawedEth[contrib];
  }
}