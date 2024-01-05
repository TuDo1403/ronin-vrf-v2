// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IRequestManager {
  /// @dev Throwed when the request hash is not found
  error RequestHashNotFound();
  /// @dev Throwed when the storage access is locked
  error Locked();

  /**
   * @dev Returns the random nonce that requested for the consumer `consumer`.
   */
  function getRandomRequestNonce(address consumer) external view returns (uint256 nonce);

  /**
   * @dev Returns whether the request is finalized or not.
   */
  function requestFinalized(bytes32 reqHash) external view returns (bool);

  /**
   * @dev Returns the random request hash. Reverts if not found.
   */
  function getRandomRequestHash(address consumer, uint256 nonce) external view returns (bytes32 hash);
}
