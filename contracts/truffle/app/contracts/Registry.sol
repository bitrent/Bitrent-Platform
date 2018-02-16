pragma solidity ^0.4.18;

import './base/PermissionManager.sol';
import './base/Ownable.sol';

contract Registry is Ownable {

  struct ContributorData {
    bool isActive;
    uint contributionETH;
    uint contributionUSD;
    uint tokensIssued;
    uint quoteUSD;
    uint contributionRNTB;
  }
  mapping(address => ContributorData) public contributorList;
  mapping(uint => address) private contributorIndexes;

  uint private nextContributorIndex;

  /* Permission manager contract */
  PermissionManager public permissionManager;

  bool public completed;

  modifier onlyPermitted() {
    require(permissionManager.isPermitted(msg.sender));
    _;
  }

  event ContributionAdded(address _contributor, uint overallEth, uint overallUSD, uint overallToken, uint quote);
  event ContributionEdited(address _contributor, uint overallEth, uint overallUSD,  uint overallToken, uint quote);
  function Registry(address pManager) public {
    permissionManager = PermissionManager(pManager); 
    completed = false;
  }

  function setPermissionManager(address _permadr) public onlyOwner {
    require(_permadr != 0x0);
    permissionManager = PermissionManager(_permadr);
  }

  function isActiveContributor(address contributor) public view returns(bool) {
    return contributorList[contributor].isActive;
  }

  function removeContribution(address contributor) public onlyPermitted {
    contributorList[contributor].isActive = false;
  }

  function setCompleted(bool compl) public onlyPermitted {
    completed = compl;
  }

  function addContribution(address _contributor, uint _amount, uint _amusd, uint _tokens, uint _quote ) public onlyPermitted {
    
    if (contributorList[_contributor].isActive == false) {
        contributorList[_contributor].isActive = true;
        contributorList[_contributor].contributionETH = _amount;
        contributorList[_contributor].contributionUSD = _amusd;
        contributorList[_contributor].tokensIssued = _tokens;
        contributorList[_contributor].quoteUSD = _quote;

        contributorIndexes[nextContributorIndex] = _contributor;
        nextContributorIndex++;
    } else {
      contributorList[_contributor].contributionETH += _amount;
      contributorList[_contributor].contributionUSD += _amusd;
      contributorList[_contributor].tokensIssued += _tokens;
      contributorList[_contributor].quoteUSD = _quote;
    }
    ContributionAdded(_contributor, contributorList[_contributor].contributionETH, contributorList[_contributor].contributionUSD, contributorList[_contributor].tokensIssued, contributorList[_contributor].quoteUSD);
  }

  function editContribution(address _contributor, uint _amount, uint _amusd, uint _tokens, uint _quote) public onlyPermitted {
    if (contributorList[_contributor].isActive == true) {
        contributorList[_contributor].contributionETH = _amount;
        contributorList[_contributor].contributionUSD = _amusd;
        contributorList[_contributor].tokensIssued = _tokens;
        contributorList[_contributor].quoteUSD = _quote;
    }
     ContributionEdited(_contributor, contributorList[_contributor].contributionETH, contributorList[_contributor].contributionUSD, contributorList[_contributor].tokensIssued, contributorList[_contributor].quoteUSD);
  }

  function addContributor(address _contributor, uint _amount, uint _amusd, uint _tokens, uint _quote) public onlyPermitted {
    contributorList[_contributor].isActive = true;
    contributorList[_contributor].contributionETH = _amount;
    contributorList[_contributor].contributionUSD = _amusd;
    contributorList[_contributor].tokensIssued = _tokens;
    contributorList[_contributor].quoteUSD = _quote;
    contributorIndexes[nextContributorIndex] = _contributor;
    nextContributorIndex++;
    ContributionAdded(_contributor, contributorList[_contributor].contributionETH, contributorList[_contributor].contributionUSD, contributorList[_contributor].tokensIssued, contributorList[_contributor].quoteUSD);
 
  }

  function getContributionETH(address _contributor) public view returns (uint) {
      return contributorList[_contributor].contributionETH;
  }

  function getContributionUSD(address _contributor) public view returns (uint) {
      return contributorList[_contributor].contributionUSD;
  }

  function getContributionRNTB(address _contributor) public view returns (uint) {
      return contributorList[_contributor].contributionRNTB;
  }

  function getContributionTokens(address _contributor) public view returns (uint) {
      return contributorList[_contributor].tokensIssued;
  }

  function addRNTBContribution(address _contributor, uint _amount) public onlyPermitted {
    if (contributorList[_contributor].isActive == false) {
        contributorList[_contributor].isActive = true;
        contributorList[_contributor].contributionRNTB = _amount;
        contributorIndexes[nextContributorIndex] = _contributor;
        nextContributorIndex++;
    } else {
      contributorList[_contributor].contributionETH += _amount;
    }
  }

  function getContributorByIndex(uint index) public view  returns (address) {
      return contributorIndexes[index];
  }

  function getContributorAmount() public view returns(uint) {
      return nextContributorIndex;
  }

}