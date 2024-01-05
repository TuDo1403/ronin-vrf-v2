// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IOracleManager } from "./IOracleManager.sol";
import { LibSLA } from "../../libraries/LibSLA.sol";

/**
 * @title IOracleManagerExtended
 * @dev Extended interface for managing oracles with additional functionality.
 */
interface IOracleManagerExtended is IOracleManager {
  /**
   * @dev Error thrown when the length of provided arrays does not match.
   */
  error LengthMismatch();

  /**
   * @dev Error thrown when attempting to use a null value at a specific index.
   * @param index The index of the null value.
   */
  error NullValue(uint256 index);

  /**
   * @dev Error thrown when a key hash does not exist.
   * @param keyHash The key hash that does not exist.
   */
  error UnexistedKeyHash(bytes32 keyHash);

  /**
   * @dev Error thrown when attempting to add a duplicate oracle for a key hash.
   * @param keyHash The key hash for which the oracle is duplicated.
   * @param oracleAddr The address of the duplicate oracle.
   */
  error DuplicateOracle(bytes32 keyHash, address oracleAddr);

  /**
   * @dev Error thrown when attempting to add a key hash that is already present.
   * @param keyHash The key hash that is already added.
   */
  error KeyHashAlreadyAdded(bytes32 keyHash);

  /**
   * @dev Represents information about an oracle.
   * @param oracleAddr The address of the oracle.
   * @param assignedCount The number of times the operator is assigned for fulfillRandomSeed.
   * @param fulFilledCount The number of times the operator fulfilled the request.
   * @param infoUpdatedAtBlock The time the operator is updated with CRUD.
   */
  struct Oracle {
    address oracleAddr;
    uint256 infoUpdatedAtBlock;
  }

  event PeriodDurationUpdated(address indexed by, uint256 periodDuration);

  /**
   * @dev Emitted when the threshold for fulfilling the request is updated.
   * @param by The address that updated the threshold for fulfilling the request.
   * @param numBlock The new number of blocks for the threshold for fulfilling the request.
   */
  event MaxResponseBlockUpdated(address indexed by, uint256 numBlock);

  /**
   * @dev Emitted when the oracles are updated.
   * @param keyHashes The key hashes of the updated oracles.
   * @param oracleAddrs The addresses of the updated oracles.
   */
  event OracleUpdated(bytes32[] keyHashes, address[] oracleAddrs);

  /**
   * @dev Gets the current threshold for fulfilling the request in blocks.
   * @return numBlock The number of blocks for the threshold for fulfilling the request.
   */
  function getMaxResponseBlock() external view returns (uint256 numBlock);

  /**
   * @dev Sets the threshold for fulfilling the request. Should be called by the admin.
   * @param numBlock The new number of blocks for the threshold for fulfilling the request.
   */
  function setMaxResponseBlock(uint256 numBlock) external;

  /**
   * @dev Updates information about multiple oracles.
   * @param keyHashes The key hashes of the oracles to be updated.
   * @param oracleAddrs The addresses of the oracles to be updated.
   */
  function updateOracles(bytes32[] calldata keyHashes, address[] calldata oracleAddrs) external;

  /**
   * @dev Gets all the key hashes of the oracles.
   * @return keyHashes The key hashes of all the oracles.
   */
  function getAllKeyHashes() external view returns (bytes32[] memory keyHashes);

  /**
   * @dev Gets the key hash associated with a specific oracle address.
   * @param oracleAddr The address of the oracle.
   * @return keyHash The key hash associated with the oracle address.
   */
  function getKeyHashOf(address oracleAddr) external view returns (bytes32 keyHash);

  /**
   * @dev Gets information about a specific oracle.
   * @param keyHash The key hash of the oracle.
   * @return oracleInfo The information about the oracle.
   */
  function getOracleInfo(bytes32 keyHash) external view returns (Oracle memory oracleInfo);
}
