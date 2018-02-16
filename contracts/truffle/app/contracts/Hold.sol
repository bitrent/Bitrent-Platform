pragma solidity ^0.4.18;

import './UnityToken.sol';
import './base/Ownable.sol';
import './base/PermissionManager.sol';
import './Registry.sol';
import './Observer.sol';

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
    
    address multisig;
    Registry registry;

    PermissionManager permissionManager;
    uint nextContributorToTransferEth;
    Observer observer;
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
        require(msg.sender == address(observer));
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
        observer = Observer(observerAddr);
    }

    function setPermissionManager(address _permadr) public onlyOwner {
        require(_permadr != 0x0);
        permissionManager = PermissionManager(_permadr);
    }

    function setObserver(address observerAddr) public onlyOwner {
        observer = Observer(observerAddr);
    }

    function setInitialBalance(uint inBal) public {
        initialBalance = inBal;
        InitialBalanceChanged(inBal);
    }

    function releaseAllETH() onlyPermitted public {
        uint balReleased = getBalanceReleased();
        require(this.balance >= balReleased);
        multisig.transfer(balReleased);
        withdrawed += balReleased;
        EthReleased(balReleased);
    }

    function releaseETH(uint n) onlyPermitted public {
        require(this.balance >= n);
        require(getBalanceReleased() >= n);
        multisig.transfer(n);
        withdrawed += n;
        EthReleased(n);
    } 

    function getBalance() public view returns (uint) {
        return this.balance;
    }

    function changeStageAndReleaseETH() public onlyObserver {
        uint8 newStage = currentStage + 1;
        require(newStage <= stages);
        currentStage = newStage;
        StageChanged(newStage);
        releaseAllETH();
    }

    function changeStage() public onlyObserver {
        uint8 newStage = currentStage + 1;
        require(newStage <= stages);
        currentStage = newStage;
        StageChanged(newStage);
    }

    function getBalanceReleased() public view returns (uint) {
        return initialBalance * percentage * currentStage / 100 - withdrawed ;
    }

    function returnETHByOwner() public onlyOwner {
        require(now > dateDeployed + 183 days);
        uint balance = getBalance();
        owner.transfer(getBalance());
        EthReturnedToOwner(owner, balance);
    }

    function refund(uint _numberOfReturns) public onlyPermitted {
        address currentParticipantAddress;

        for (uint cnt = 0; cnt < _numberOfReturns; cnt++) {
            currentParticipantAddress = registry.getContributorByIndex(nextContributorToTransferEth);
            if (currentParticipantAddress == 0x0) 
                return;

            if (!hasWithdrawedEth[currentParticipantAddress]) {
                uint EthAmount = registry.getContributionETH(currentParticipantAddress);
                EthAmount -=  EthAmount * (percentage / 100 * currentStage);

                currentParticipantAddress.transfer(EthAmount);
                EthRefunded(currentParticipantAddress, EthAmount);
                hasWithdrawedEth[currentParticipantAddress] = true;
            }
            nextContributorToTransferEth += 1;
        }
        
    }  

    function() public payable {

    }
}