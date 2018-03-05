pragma solidity ^0.4.18;
/**
 * @author Emil Dudnyk
 */
contract ETHPriceWatcher {
  address public ethPriceProvider;

  modifier onlyEthPriceProvider() {
    require(msg.sender == ethPriceProvider);
    _;
  }

  function receiveEthPrice(uint ethUsdPrice) external;

  function setEthPriceProvider(address provider) external;
}