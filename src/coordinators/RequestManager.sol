// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { StorageSlot } from "@openzeppelin/contracts/utils/StorageSlot.sol";
import { IRequestManager, IRequestManagerExtended } from "../interfaces/coordinators/IRequestManagerExtended.sol";

abstract contract RequestManager is IRequestManagerExtended {
  using StorageSlot for bytes32;

  /// @dev Custom storage slot for boolean `lock` used for protecting against reetrancy.
  bytes32 internal constant $_LOCK_STORAGE =
    keccak256(abi.encode(uint256(keccak256("@ronin-vrf.RequestManager.storage.lock")) - 1)) & ~bytes32(uint256(0xff));
  /// @dev Mapping from consumer contract => nonce
  mapping(address consumer => uint256 nonce) internal _requestNonce;
  /// @dev Mapping from consumer contract => nonce => request hash
  mapping(address consumer => mapping(uint256 nonce => bytes32 reqHash)) internal _requestHash;
  /// @dev Mapping from request hash => request status
  mapping(bytes32 reqHash => RequestStatus reqStatus) internal _requestStatus;

  modifier whenNotLocked() {
    _requireNotLocked();
    _;
  }

  /**
   * @inheritdoc IRequestManager
   */
  function getRandomRequestNonce(address consumer) external view returns (uint256 nonce) {
    nonce = _requestNonce[consumer];
  }

  /**
   * @inheritdoc IRequestManager
   */
  function requestFinalized(bytes32 reqHash) external view whenNotLocked returns (bool finalized) {
    finalized = _requestStatus[reqHash].finalizedBy != address(0x0);
  }

  /**
   * @inheritdoc IRequestManagerExtended
   */
  function requestFinalizedBy(bytes32 reqHash) external view whenNotLocked returns (address finalizedBy) {
    finalizedBy = _requestStatus[reqHash].finalizedBy;
  }

  /**
   * @inheritdoc IRequestManagerExtended
   */
  function requestFulfillOrder(bytes32 reqHash) external view returns (bytes32[] memory keyHashesByOrder) {
    keyHashesByOrder = _requestStatus[reqHash].keyHashesByOrder;
  }

  /**
   * @inheritdoc IRequestManager
   */
  function getRandomRequestHash(address consumer, uint256 nonce) external view returns (bytes32 hash) {
    hash = _requestHash[consumer][nonce];
    if (hash == bytes32(0x0)) revert RequestHashNotFound();
  }

  /**
   * @dev Internal function to require that the storage access is not locked.
   */
  function _requireNotLocked() internal view {
    if (StorageSlot.getBooleanSlot($_LOCK_STORAGE).value) revert Locked();
  }
}
