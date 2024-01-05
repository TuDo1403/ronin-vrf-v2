// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IOracleManager {
  /// @dev Throwed when the array length is invalid.
  error InvalidArrayLength();

  /// @dev Emitted when the oracles are added.
  event OraclesAdded(bytes32[] keyHashes, address[] oracleAddrs);
  /// @dev Emitted when the oracles are removed.
  event OraclesRemoved(bytes32[] keyHashes);

  /**
   * @dev Returns oracle address.
   */
  function oracleAddress(bytes32 keyHash) external view returns (address oracle);

  /**
   * @dev Adds the oracle list.
   *
   * Requirement:
   * - The method caller is the contract admin.
   *
   * Emits the `OraclesAdded` event.
   *
   */
  function addOracles(bytes32[] calldata keyHashes, address[] calldata oracleAddrs) external;

  /**
   * @dev Removes the oracle list.
   *
   * Requirement:
   * - The method caller is the contract admin.
   *
   * Emits the `OraclesRemoved` event.
   *
   */
  function removeOracles(bytes32[] calldata keyHashes) external;
}
