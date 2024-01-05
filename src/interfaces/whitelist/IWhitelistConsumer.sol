// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IWhitelistConsumer {
  /// @dev Reverts when consumer address is not whitelisted.
  error ErrUnauthorizedConsumer();

  /**
   * @dev Emitted when an address is whitelisted or blacklisted.
   * @param addr The address that is whitelisted or blacklisted.
   * @param status The whitelisted status (true if whitelisted, false otherwise).
   */
  event AddressWhitelisted(address indexed addr, bool indexed status);
  /**
   * @dev Emitted when the whitelist status for all addresses is changed.
   * @param status The new whitelist status for all addresses.
   */
  event WhitelistAllChanged(bool indexed status);

  /**
   * @dev Sets the whitelisted status for a specific address.
   * @param addr The address to set the whitelisted status for.
   * @param status The new whitelisted status (true if whitelisted, false otherwise).
   */
  function whitelist(address addr, bool status) external;

  /**
   * @dev Sets the whitelist status for all addresses.
   * @param status The new whitelist status for all addresses (true if whitelisted, false otherwise).
   */
  function whitelistAllAddresses(bool status) external;

  /**
   * @dev Checks whether an address is whitelisted.
   * @param addr The address to check for whitelisted status.
   * @return Whether the address is whitelisted.
   */
  function isWhitelisted(address addr) external view returns (bool);

  /**
   * @dev Retrieves the current whitelist status for all addresses.
   * @return Whether all addresses are whitelisted.
   */
  function whitelistedAll() external view returns (bool);
}
