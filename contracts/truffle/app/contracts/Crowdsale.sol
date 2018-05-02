pragma solidity ^0.4.21;

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

  enum SaleState  {NEW, SALE, ENDED}

  // minimum goal USD
  uint public softCap;
  // maximum goal USD
  uint public hardCap;
  // maximum goal UNT
  uint public hardCapToken;

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
  uint public withdrawedTokens;
  // minimum ETH investment amount
  uint public minimalContribution;

  bool releasedTokens;
  BuildingStatus public statusI;

  PermissionManager public permissionManager;

  //minimum of tokens that must be on the contract for the start
  uint private minimumTokensToStart;
  SaleState public state;

  uint private nextContributorToClaim;
  uint private nextContributorToTransferTokens;

  mapping(address => bool) private hasWithdrawedTokens; //address who got a tokens

  /* Events */
  event CrowdsaleStarted(uint blockNumber);
  event CrowdsaleEnded(uint blockNumber);
  event SoftCapReached(uint blockNumber);
  event HardCapReached(uint blockNumber);
  event ContributionAdded(address contrib, uint amount, uint amusd, uint tokens, uint ethusdrate);
  event ContributionAddedManual(address contrib, uint amount, uint amusd, uint tokens, uint ethusdrate);
  event ContributionEdit(address contrib, uint amount, uint amusd, uint tokens, uint ethusdrate);
  event ContributionRemoved(address contrib, uint amount, uint amusd, uint tokens);
  event TokensTransfered(address contributor, uint amount);
  event ErrorSendingETH(address to, uint amount);
  event WithdrawedEthToHold(uint amount);
  event ManualChangeStartDate(uint beforeDate, uint afterDate);
  event ManualChangeEndDate(uint beforeDate, uint afterDate);
  event TokensTransferedToHold(address hold, uint amount);
  event TokensTransferedToOwner(address hold, uint amount);
  event ChangeMinAmount(uint oldMinAmount, uint minAmount);
  event ChangePreSale(address preSale);
  event ChangeTokenUSDRate(uint oldTokenUSDRate, uint tokenUSDRate);
  event ChangeHardCapToken(uint oldHardCapToken, uint newHardCapToken);
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
    hardCapToken = 100000 * 1 ether;

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
    emit ChangeTokenUSDRate(oldTokenUSDRate, _tokenUSDRate);
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
    emit ManualChangeStartDate(oldStartDate, date);
  }

  function setEndDate(uint date) public onlyOwner {
    uint oldEndDate = endDate;
    endDate = date;
    emit ManualChangeEndDate(oldEndDate, date);
  }

  function setSoftCap(uint _softCap) public onlyOwner {
    softCap = _softCap * 1 ether;
    emit SoftCapChanged();
  }

  function setHardCap(uint _hardCap) public onlyOwner {
    hardCap = _hardCap * 1 ether;
    emit HardCapChanged();
  }

  function setMinimalContribution(uint minimumAmount) public onlyOwner {
    uint oldMinAmount = minimalContribution;
    minimalContribution = minimumAmount;
    emit ChangeMinAmount(oldMinAmount, minimalContribution);
  }

  function setHardCapToken(uint _hardCapToken) public onlyOwner {
    require(_hardCapToken > 1 ether); // > 1 UNT
    uint oldHardCapToken = _hardCapToken;
    hardCapToken = _hardCapToken;
    emit ChangeHardCapToken(oldHardCapToken, hardCapToken);
  }

  /* The function without name is the default function that is called whenever anyone sends funds to a contract */
  function() whenNotPaused public payable {
    require(state == SaleState.SALE);
    require(now >= startDate);
    require(msg.value >= minimalContribution);

    bool ckeck = checkCrowdsaleState(msg.value);

    if(ckeck) {
      processTransaction(msg.sender, msg.value);
    } else {
      msg.sender.transfer(msg.value);
    }
  }

  /**
   * @dev Checks if the goal or time limit has been reached and ends the campaign
   * @return false when contract does not accept tokens
   */
  function checkCrowdsaleState(uint _amount) internal returns (bool) {
    uint usd = _amount.mul(ethUsdPrice);
    if (usdRaised.add(usd) >= hardCap) {
      state = SaleState.ENDED;
      statusI.setStatus(BuildingStatus.statusEnum.preparation_works);
      emit HardCapReached(block.number);
      emit CrowdsaleEnded(block.number);
      return true;
    }

    if (now > endDate) {
        state = SaleState.ENDED;
        statusI.setStatus(BuildingStatus.statusEnum.preparation_works);
        emit CrowdsaleEnded(block.number);
        return false;
    }
    return true;
  }

  /**
 * @dev Token purchase
 */
  function processTransaction(address _contributor, uint _amount) internal {

    require(msg.value >= minimalContribution);

    uint maxContribution = calculateMaxContributionUsd();
    uint contributionAmountUsd = _amount.mul(ethUsdPrice);
    uint contributionAmountETH = _amount;

    uint returnAmountETH = 0;

    if (maxContribution < contributionAmountUsd) {
      contributionAmountUsd = maxContribution;
      uint returnAmountUsd = _amount.mul(ethUsdPrice) - maxContribution;
      returnAmountETH = contributionAmountETH - returnAmountUsd.div(ethUsdPrice);
      contributionAmountETH = contributionAmountETH.sub(returnAmountETH);
    }

    if (usdRaised + contributionAmountUsd >= softCap && softCap > usdRaised) {
      emit SoftCapReached(block.number);
    }

    // get tokens from eth Usd msg.value * ethUsdPrice / tokenUSDRate
    // 1 ETH * 860 $ / 445 $ = 193258426966292160 wei = 1.93 UNT
    uint tokens = contributionAmountUsd.div(tokenUSDRate);

    if(totalTokens + tokens > hardCapToken) {
      _contributor.transfer(_amount);
    } else {
      if (tokens > 0) {
        registry.addContribution(_contributor, contributionAmountETH, contributionAmountUsd, tokens, ethUsdPrice);
        ethRaised += contributionAmountETH;
        totalTokens += tokens;
        usdRaised += contributionAmountUsd;

        if(token.transfer(msg.sender, tokens)) {
          emit TokensTransfered(msg.sender, tokens);
          withdrawedTokens += tokens;
          hasWithdrawedTokens[msg.sender] = true;
        }

        emit ContributionAdded(_contributor, contributionAmountETH, contributionAmountUsd, tokens, ethUsdPrice);
      }
    }

    if (returnAmountETH != 0) {
      _contributor.transfer(returnAmountETH);
    }
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

  function calculateMaxContributionUsd() public constant returns (uint) {
    return hardCap - usdRaised;
  }

  function calculateMaxTokensIssued() public constant returns (uint) {
    return hardCapToken - totalTokens;
  }

  function calculateMaxEthIssued() public constant returns (uint) {
    return hardCap.mul(ethUsdPrice) - usdRaised.mul(ethUsdPrice);
  }

  function getEthRaised() public view returns (uint) {
    return ethRaised;
  }

  function checkBalanceContract() internal view returns (uint) {
    return token.balanceOf(this);
  }

  function getContributorTokens(address contrib) public view returns (uint) {
    return registry.getContributionTokens(contrib);
  }

  function getContributorETH(address contrib) public view returns (uint) {
    return registry.getContributionETH(contrib);
  }

  function getContributorUSD(address contrib) public view returns (uint) {
    return registry.getContributionUSD(contrib);
  }

  function getTokens() public whenNotPaused {
    require((now > endDate && usdRaised >= softCap ) || (usdRaised >= hardCap)  );
    require(state == SaleState.ENDED);
    require(!hasWithdrawedTokens[msg.sender] && registry.isActiveContributor(msg.sender));
    require(getTokenBalance() >= registry.getContributionTokens(msg.sender));

    uint numberOfUNT = registry.getContributionTokens(msg.sender);

    if(token.transfer(msg.sender, numberOfUNT)) {
      emit TokensTransfered(msg.sender, numberOfUNT);
      withdrawedTokens += numberOfUNT;
      hasWithdrawedTokens[msg.sender] = true;
    }

  }

  function getOverTokens() public onlyOwner {
    require(checkBalanceContract() > (totalTokens - withdrawedTokens));
    uint balance = checkBalanceContract() - (totalTokens - withdrawedTokens);
    if(balance > 0) {
      if(token.transfer(msg.sender, balance)) {
        emit TokensTransfered(msg.sender,  balance);
      }
    }
  }

  /**
   * @dev transfer funds ETH to multisig wallet if reached minimum goal
   */
  function withdrawEth() public onlyOwner {
    require(state == SaleState.ENDED);
    uint bal = address(this).balance;
    address(hold).transfer(bal);
    hold.setInitialBalance(bal);
    emit WithdrawedEthToHold(bal);
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
    emit CrowdsaleStarted(block.number);
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

  function getContributorAmount() public view returns (uint) {
    return registry.getContributorAmount();
  }

  function getWithdrawed(address contrib) public view returns (bool) {
    return hasWithdrawedTokens[contrib];
  }

  function addContributor(address _contributor, uint _amount, uint _amusd, uint _tokens, uint _quote) public onlyPermitted {
    registry.addContributor(_contributor, _amount, _amusd, _tokens, _quote);
    ethRaised += _amount;
    usdRaised += _amusd;
    totalTokens += _tokens;
    emit ContributionAddedManual(_contributor, ethRaised, usdRaised, totalTokens, _quote);

  }

  function editContribution(address _contributor, uint _amount, uint _amusd, uint _tokens, uint _quote) public onlyPermitted {
    ethRaised -= registry.getContributionETH(_contributor);
    usdRaised -= registry.getContributionUSD(_contributor);
    totalTokens -= registry.getContributionTokens(_contributor);

    registry.editContribution(_contributor, _amount, _amusd, _tokens, _quote);
    ethRaised += _amount;
    usdRaised += _amusd;
    totalTokens += _tokens;
    emit ContributionAdded(_contributor, ethRaised, usdRaised, totalTokens, _quote);

  }

  function removeContributor(address _contributor) public onlyPermitted {
    registry.removeContribution(_contributor);
    ethRaised -= registry.getContributionETH(_contributor);
    usdRaised -= registry.getContributionUSD(_contributor);
    totalTokens -= registry.getContributionTokens(_contributor);
    emit ContributionRemoved(_contributor, ethRaised, usdRaised, totalTokens);
  }

}