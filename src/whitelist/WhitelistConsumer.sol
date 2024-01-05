// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IWhitelistConsumer } from "../interfaces/whitelist/IWhitelistConsumer.sol";

abstract contract WhitelistConsumer is Ownable, IWhitelistConsumer {
  /// @dev Gap for upgradability.
  uint256[40] private ____gap;

  /// @dev mapping from consumer address to whitelist boolean indicator.
  mapping(address consumer => bool whitelisted) internal _whitelisted;
  /// @dev boolean indicate if all addresses is whitelisted.
  bool internal _whitelistedAll;

  modifier onlyWhitelisted(address consumer) {
    if (!isWhitelisted(consumer)) revert ErrUnauthorizedConsumer();
    _;
  }

  /**
   * @inheritdoc IWhitelistConsumer
   */
  function whitelist(address addr, bool status) external onlyOwner {
    _whitelisted[addr] = status;
    emit AddressWhitelisted(addr, status);
  }

  /**
   * @inheritdoc IWhitelistConsumer
   */
  function whitelistAllAddresses(bool status) external onlyOwner {
    _whitelistedAll = status;
    emit WhitelistAllChanged(status);
  }

  /**
   * @inheritdoc IWhitelistConsumer
   */
  function isWhitelisted(address addr) public view returns (bool) {
    return whitelistedAll() || _whitelisted[addr];
  }

  /**
   * @inheritdoc IWhitelistConsumer
   */
  function whitelistedAll() public view returns (bool) {
    return _whitelistedAll;
  }
}
