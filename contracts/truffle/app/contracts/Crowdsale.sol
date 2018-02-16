pragma solidity ^0.4.18;

import './UnityToken.sol';
import './base/Pausable.sol';

import './ConvertQuote.sol';
import './Hold.sol';
import './Registry.sol';
import './base/ETHPriceWatcher.sol';
import './ERC223/ERC223_receiving_contract.sol';
import './base/BuildingStatus.sol';

contract Crowdsale is Pausable, ETHPriceWatcher, ERC223ReceivingContract {
  using SafeMath for uint256;

  UnityToken public token;

  Hold hold;
  ConvertQuote convert;
  Registry registry;

  enum SaleState  { NEW, SALE, ENDED, REFUND }

  // minimum goal ETH
  uint public softCap;
  // maximum goal ETH
  uint public hardCap;

  // start and end timestamps where investments are allowed
  uint public startDate;
  uint public endDate;

  uint public ethUsdPrice; // in cents
  uint public tokenUSDRate; // in cents

  // total ETH collected
  uint private ethRaised;
  // total USD collected
  uint private usdRaised;

  // total token sales
  uint private totalTokens;
  // how many tokens sent to investors
  uint private withdrawedTokens;
  // minimum ETH investment amount
  uint public minimalContribution;

  bool releasedTokens;
  BuildingStatus statusI;

  PermissionManager public permissionManager;

  //minimum of tokens that must be on the contract for the start
  uint private minimumTokensToStart;
  SaleState public state;

  uint private nextContributorToClaim;
  uint private nextContributorToTransferTokens;

  mapping(address => bool) private hasWithdrawedTokens; //address who got a tokens
  mapping(address => bool) private hasRefunded; //address who got a tokens

  /* Events */
  event CrowdsaleStarted(uint blockNumber);
  event CrowdsaleEnded(uint blockNumber);
  event SoftCapReached(uint blockNumber);
  event HardCapReached(uint blockNumber);
  event ContributionAdded(address contrib, uint amount, uint amusd, uint tokens, uint ethusdrate);
  event ContributionAddedManual(address contrib, uint amount, uint amusd, uint tokens, uint ethusdrate);
  event ContributionEdit(address contrib, uint amount, uint amusd, uint tokens, uint ethusdrate);
  event ContributionRemoved(address contrib, uint amount, uint amusd, uint tokens);
  event TokensTransfered(address contributor , uint amount);
  event Refunded(address ref, uint amount);
  event ErrorSendingETH(address to, uint amount);
  event WithdrawedEthToHold(uint amount);
  event ManualChangeStartDate(uint beforeDate, uint afterDate);
  event ManualChangeEndDate(uint beforeDate, uint afterDate);
  event TokensTransferedToHold(address hold, uint amount);
  event TokensTransferedToOwner(address hold, uint amount);
  event ChangeMinAmount(uint oldMinAmount, uint minAmount);
  event ChangePreSale(address preSale);
  event ChangeTokenUSDRate(uint oldTokenUSDRate, uint tokenUSDRate);
  event SoftCapChanged();
  event HardCapChanged();

  modifier onlyPermitted() {
      require(permissionManager.isPermitted(msg.sender) || msg.sender == owner);
      _;
  }

  function Crowdsale(
    address tokenAddress,
    address registryAddress,
    address _permissionManager,
    uint start,
    uint end,
    uint _softCap,
    uint _hardCap,
    address holdCont,
    uint _ethUsdPrice) public
  {
    token = UnityToken(tokenAddress);
    permissionManager = PermissionManager(_permissionManager);
    state = SaleState.NEW;
    
    startDate = start;
    endDate = end;
    minimalContribution = 0.3 * 1 ether;
    tokenUSDRate = 44500; //445.00$ in cents
    releasedTokens = false;

    softCap = _softCap * 1 ether;
    hardCap = _hardCap * 1 ether;

    ethUsdPrice = _ethUsdPrice;

    hold = Hold(holdCont);
    registry = Registry(registryAddress);
    
  }


  function setPermissionManager(address _permadr) public onlyOwner {
    require(_permadr != 0x0);
    permissionManager = PermissionManager(_permadr);
  }


  function setRegistry(address _regadr) public onlyOwner {
    require(_regadr != 0x0);
    registry = Registry(_regadr);
  }

  function setTokenUSDRate(uint _tokenUSDRate) public onlyOwner {
    require(_tokenUSDRate > 0);
    uint oldTokenUSDRate = tokenUSDRate;
    tokenUSDRate = _tokenUSDRate;
    ChangeTokenUSDRate(oldTokenUSDRate, _tokenUSDRate);
  }

  function getTokenUSDRate() public view returns (uint) {
    return tokenUSDRate;
  }

  function receiveEthPrice(uint _ethUsdPrice) external onlyEthPriceProvider {
    require(_ethUsdPrice > 0);
    ethUsdPrice = _ethUsdPrice;
  }

  function setEthPriceProvider(address provider) external onlyOwner {
    require(provider != 0x0);
    ethPriceProvider = provider;
  }

  /* Setters */
  function setHold(address holdCont) public onlyOwner {
    require(holdCont != 0x0);
    hold = Hold(holdCont);
  }

  function setToken(address tokCont) public onlyOwner {
    require(tokCont != 0x0);
    token = UnityToken(tokCont);
  }

  function setStatusI(address statI) public onlyOwner {
    require(statI != 0x0);
    statusI = BuildingStatus(statI);
  }

  function setStartDate(uint date) public onlyOwner {
    uint oldStartDate = startDate;
    startDate = date;
    ManualChangeStartDate(oldStartDate, date);
  }
  function setEndDate(uint date) public onlyOwner {
    uint oldEndDate = endDate;
    endDate = date;
    ManualChangeEndDate(oldEndDate, date);
  }
  function setSoftCap(uint _softCap) public onlyOwner {
    softCap = _softCap * 1 ether;
    SoftCapChanged();
  }
  function setHardCap(uint _hardCap) public onlyOwner {
    hardCap = _hardCap * 1 ether;
    HardCapChanged();
  }
  function setMinimalContribution(uint minimumAmount) public onlyOwner {
    uint oldMinAmount = minimalContribution;
    minimalContribution = minimumAmount;
    ChangeMinAmount(oldMinAmount, minimalContribution);
  }

  /* The function without name is the default function that is called whenever anyone sends funds to a contract */
  function() whenNotPaused public payable {
    require(msg.value != 0);
    require(state == SaleState.SALE);
    checkCrowdsaleState(msg.value);
    processTransaction(msg.sender, msg.value);
  }

  /**
   * @dev Checks if the goal or time limit has been reached and ends the campaign
   * @return false when contract does not accept tokens
   */
  function checkCrowdsaleState(uint _amount) internal returns (bool) {
    uint usd = _amount.mul(ethUsdPrice);
    if (usdRaised.add(usd) >= hardCap) {
      state = SaleState.ENDED;
      HardCapReached(block.number); // Close the crowdsale
      CrowdsaleEnded(block.number);
    }

    if (now > endDate) {
      if (usdRaised.add(usd) >= softCap) {
          state = SaleState.ENDED;
          statusI.setStatus(BuildingStatus.statusEnum.preparation_works);
          CrowdsaleEnded(block.number);
      } else {
          state = SaleState.REFUND;   
          statusI.setStatus(BuildingStatus.statusEnum.refund);
          CrowdsaleEnded(block.number);
      }
    }
  }

  /**
   * @dev Token purchase
   */
  function processTransaction(address _contributor, uint _amount) internal {

    require(msg.value >= minimalContribution);

    // get tokens from eth Usd msg.value * ethUsdPrice / tokenUSDRate
    // 1 ETH * 835,92$ / 386.61 = 2162178940017071467 wei =

    uint usd = _amount.mul(ethUsdPrice);
    uint tokens = _amount.mul(ethUsdPrice).div(tokenUSDRate);

    if (usdRaised + usd >= softCap && softCap > usdRaised) {
      SoftCapReached(block.number);
    }

    usdRaised += usd;

    registry.addContribution(_contributor, _amount, usd, tokens, ethUsdPrice);
    ethRaised += _amount;
    totalTokens += tokens;
    ContributionAdded(_contributor, _amount, usd, tokens, ethUsdPrice);

  }

  function getTokensIssued() public view returns (uint) {
    return totalTokens;
  }

  function getTotalUSDInTokens() public view returns (uint) {
    return totalTokens.mul(tokenUSDRate);
  }

  function getUSDRaised() public view returns (uint) {
    return usdRaised;
  }

  function getEthRaised() public view returns (uint) {
    return ethRaised;
  }

  function checkBalanceContract() internal view returns (uint) {
    return token.balanceOf(this);
  }

  function getContributorTokens(address contrib) public view returns(uint) {
    return registry.getContributionTokens(contrib);
  }

  function getContributorETH(address contrib) public view returns(uint) {
    return registry.getContributionETH(contrib);
  }

  function getContributorUSD(address contrib) public view returns(uint) {
    return registry.getContributionUSD(contrib);
  }

  function batchReturnUNT(uint _numberOfReturns) public onlyOwner whenNotPaused {
    require(state == SaleState.ENDED);

    address currentParticipantAddress;
    uint tokensCount;

    for (uint cnt = 0; cnt < _numberOfReturns; cnt++) {
      currentParticipantAddress = registry.getContributorByIndex(nextContributorToTransferTokens);
      if (currentParticipantAddress == 0x0) 
        return;

      if (!hasWithdrawedTokens[currentParticipantAddress] && registry.isActiveContributor(currentParticipantAddress)) {

        uint numberOfUNT = registry.getContributionTokens(currentParticipantAddress);
       
        token.transfer(currentParticipantAddress, numberOfUNT);
        TokensTransfered(currentParticipantAddress, numberOfUNT);
        withdrawedTokens += tokensCount;
        hasWithdrawedTokens[currentParticipantAddress] = true;
      }

      nextContributorToTransferTokens += 1;
    }

  }

  /**
   * @dev if crowdsale is unsuccessful, investors can claim refunds here
   */
  function refund() public whenNotPaused {
    require(state == SaleState.REFUND);

    uint ethContributed = registry.getContributionETH(msg.sender);
    if (!msg.sender.send(ethContributed)) {
      ErrorSendingETH(msg.sender, ethContributed);
    }
     
    hasRefunded[msg.sender] = true;
    Refunded(msg.sender, ethContributed);
  }

  /**
   * @dev transfer funds ETH to multisig wallet if reached minimum goal
   */
  function withdrawEth() public onlyOwner {
    require(state == SaleState.ENDED);
    uint bal = this.balance;
    hold.transfer(bal);
    hold.setInitialBalance(bal);
    WithdrawedEthToHold(bal);
  }

  function newCrowdsale() public onlyOwner {
    state = SaleState.NEW;
  }

  /**
   * @dev Manual start crowdsale.
   */
  function startCrowdsale() public onlyOwner {
    require(now > startDate && now <= endDate);
    require(state == SaleState.NEW);

    statusI.setStatus(BuildingStatus.statusEnum.crowdsale);
    state = SaleState.SALE;
    CrowdsaleStarted(block.number);
  }

  // @return true if crowdsale event has ended
  function hasEnded() public constant returns (bool) {
    return now > endDate || state == SaleState.ENDED;
  }

  function getTokenBalance() public constant returns (uint) {
    return token.balanceOf(this);
  }

  function getSoftCap() public view returns (uint) {
    return softCap;
  }

  function getHardCap() public view returns (uint) {
    return hardCap;
  }

  function getStartDate() public view returns (uint) {
    return startDate;
  }

  function getEndDate() public view returns (uint) {
    return endDate;
  }

  function getContributorAmount() public view returns(uint) {
    return registry.getContributorAmount();
  }

  function getWithdrawed(address contrib) public view returns(bool) {
    return hasWithdrawedTokens[contrib];
  }

  function getRefunded(address contrib) public view returns(bool) {
    return hasRefunded[contrib];
  }

  function addContributor(address _contributor, uint _amount, uint _amusd, uint _tokens, uint _quote) public onlyPermitted {
    registry.addContributor(_contributor, _amount, _amusd, _tokens, _quote);
    ethRaised += _amount;
    usdRaised += _amusd;
    totalTokens += _tokens;
    ContributionAddedManual(_contributor, ethRaised, usdRaised, totalTokens, _quote);

  }

  function editContribution(address _contributor, uint _amount, uint _amusd, uint _tokens, uint _quote) public onlyPermitted {
    ethRaised -= registry.getContributionETH(_contributor);
    usdRaised -= registry.getContributionUSD(_contributor);
    totalTokens -= registry.getContributionTokens(_contributor);
    
    registry.editContribution(_contributor, _amount, _amusd, _tokens, _quote);
    ethRaised += _amount;
    usdRaised += _amusd;
    totalTokens += _tokens;
    ContributionAdded(_contributor, ethRaised, usdRaised, totalTokens, _quote);

  }

  function removeContributor(address _contributor) public onlyPermitted {
    registry.removeContribution(_contributor);
    ethRaised -= registry.getContributionETH(_contributor);
    usdRaised -= registry.getContributionUSD(_contributor);
    totalTokens -= registry.getContributionTokens(_contributor);
    ContributionRemoved(_contributor, ethRaised, usdRaised, totalTokens);
  }

}