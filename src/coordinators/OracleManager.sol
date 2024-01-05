// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IOracleManager, IOracleManagerExtended } from "../interfaces/coordinators/IOracleManagerExtended.sol";
import { LibArray } from "../libraries/LibArray.sol";
import { Record, Config } from "../libraries/LibStatTracking.sol";

abstract contract OracleManager is Initializable, Ownable, IOracleManagerExtended {
  using LibArray for *;

  /// @dev mapping from key hash to oracle status
  mapping(bytes32 keyHash => Oracle oracle) internal _oracleInfo;
  /// @dev mapping from oracle address to key hash
  mapping(address oracleAddr => bytes32 keyHash) internal _keyHashOf;
  Config internal _config;
  Record internal _record;

  modifier nonEmptyArray(bytes32[] calldata arr) {
    _requireNonEmptyArray(arr);
    _;
  }

  function __OracleManager_init_unchained(uint256 periodDuration, uint256 maxResponseBlock) internal onlyInitializing {
    _record.keyHashes.push(bytes32(0x0));
    _setPeriodDuration(periodDuration);
    _setMaxResponseBlock(maxResponseBlock);
  }

  /**
   * @inheritdoc IOracleManagerExtended
   */
  function setMaxResponseBlock(uint256 maxResponseBlock) external onlyOwner {
    _setMaxResponseBlock(maxResponseBlock);
  }

  function setPeriodDuration(uint256 periodDuration) external onlyOwner {
    _setPeriodDuration(periodDuration);
  }

  /**
   * @inheritdoc IOracleManager
   */
  function addOracles(bytes32[] calldata keyHashes, address[] calldata oracleAddrs)
    external
    nonEmptyArray(keyHashes)
    onlyOwner
  {
    _addOracleSet(keyHashes, oracleAddrs);
  }

  /**
   * @inheritdoc IOracleManagerExtended
   */
  function updateOracles(bytes32[] calldata keyHashes, address[] calldata oracleAddrs)
    external
    nonEmptyArray(keyHashes)
    onlyOwner
  {
    _updateOracleSet(keyHashes, oracleAddrs);
  }

  /**
   * @inheritdoc IOracleManager
   */
  function removeOracles(bytes32[] calldata keyHashes) external nonEmptyArray(keyHashes) onlyOwner {
    _removeOracleSet(keyHashes);
  }

  /**
   * @inheritdoc IOracleManagerExtended
   */
  function getMaxResponseBlock() public view returns (uint256 maxResponseBlock) {
    return _config.maxResponseBlock;
  }

  /**
   * @inheritdoc IOracleManager
   */
  function oracleAddress(bytes32 keyHash) external view returns (address oracle) {
    oracle = _oracleInfo[keyHash].oracleAddr;
  }

  /**
   * @inheritdoc IOracleManagerExtended
   */
  function getAllKeyHashes() public view returns (bytes32[] memory keyHashes) {
    uint256 length = _record.keyHashes.length;
    if (length == 1) return keyHashes;
    keyHashes = new bytes32[](length);
    uint256 count;
    bytes32 keyHash;

    for (uint256 i; i < length; ++i) {
      keyHash = _record.keyHashes[i];
      unchecked {
        if (keyHash != bytes32(0x0)) keyHashes[count++] = keyHash;
      }
    }

    // resize array
    assembly ("memory-safe") {
      mstore(keyHashes, count)
    }
  }

  /**
   * @inheritdoc IOracleManagerExtended
   */
  function getKeyHashOf(address oracleAddr) public view returns (bytes32 keyHash) {
    keyHash = _keyHashOf[oracleAddr];
  }

  /**
   * @inheritdoc IOracleManagerExtended
   */
  function getOracleInfo(bytes32 keyHash) public view returns (Oracle memory oracleInfo) {
    oracleInfo = _oracleInfo[keyHash];
  }

  function _setPeriodDuration(uint256 periodDuration) internal {
    _config.periodDuration = periodDuration;
    emit PeriodDurationUpdated(_msgSender(), periodDuration);
  }

  /**
   * @dev Sets the threshold for fulfilling the request and emits an event.
   * @param maxResponseBlock The new number of blocks for the threshold for fulfilling the request.
   */
  function _setMaxResponseBlock(uint256 maxResponseBlock) internal {
    _config.maxResponseBlock = maxResponseBlock;
    emit MaxResponseBlockUpdated(_msgSender(), maxResponseBlock);
  }

  /**
   * @dev Updates information about multiple oracles and emits an event.
   * @param keyHashes The key hashes of the oracles to be updated.
   * @param oracleAddrs The addresses of the oracles to be updated.
   */
  function _updateOracleSet(bytes32[] calldata keyHashes, address[] calldata oracleAddrs) private {
    bytes32 prevKeyHash;
    address prevOracle;
    if (keyHashes.length != oracleAddrs.length) revert LengthMismatch();

    for (uint256 i; i < keyHashes.length; ++i) {
      // key hash and oracle address to update must not be null
      if (keyHashes[i] == bytes32(0x0) || oracleAddrs[i] == address(0x0)) revert NullValue(i);
      // key hash to update should exist in storage before
      if ((prevOracle = getOracleInfo(keyHashes[i]).oracleAddr) == address(0x0)) revert UnexistedKeyHash(keyHashes[i]);
      // oracle address to update should not being mapped to another key hash
      if ((prevKeyHash = getKeyHashOf(oracleAddrs[i])) != bytes32(0x0)) {
        revert DuplicateOracle(prevKeyHash, oracleAddrs[i]);
      }

      // update `_oracleInfo` mapping
      _oracleInfo[keyHashes[i]].oracleAddr = oracleAddrs[i];
      _oracleInfo[keyHashes[i]].infoUpdatedAtBlock = block.number;

      // update `_keyHashOf` mapping
      _keyHashOf[oracleAddrs[i]] = keyHashes[i];
      _keyHashOf[prevOracle] = bytes32(0x0);
    }

    emit OracleUpdated(keyHashes, oracleAddrs);
  }

  /**
   * @dev Adds information about multiple oracles and emits an event.
   * @param keyHashes The key hashes of the oracles to be added.
   * @param oracleAddrs The addresses of the oracles to be added.
   */
  function _addOracleSet(bytes32[] calldata keyHashes, address[] calldata oracleAddrs) private {
    bytes32 prevKeyHash;
    if (keyHashes.length != oracleAddrs.length) revert LengthMismatch();

    for (uint256 i; i < keyHashes.length; ++i) {
      // key hash and oracle address to add must not be null
      if (keyHashes[i] == bytes32(0x0) || oracleAddrs[i] == address(0x0)) revert NullValue(i);
      // oracle to add should not mapped to another key hash
      if ((prevKeyHash = getKeyHashOf(oracleAddrs[i])) != bytes32(0x0)) {
        revert DuplicateOracle(prevKeyHash, oracleAddrs[i]);
      }
      // key hash to add should not exist in storage before
      if (getOracleInfo(keyHashes[i]).infoUpdatedAtBlock != 0) revert KeyHashAlreadyAdded(keyHashes[i]);

      // update `_keyHashes` set
      _record.keyHashes.push(keyHashes[i]);

      // update `_oracleInfo` mapping
      _oracleInfo[keyHashes[i]].oracleAddr = oracleAddrs[i];
      _oracleInfo[keyHashes[i]].infoUpdatedAtBlock = block.number;

      // update `_keyHashOf` mapping
      _keyHashOf[oracleAddrs[i]] = keyHashes[i];
    }

    _record.keyHashCount += keyHashes.length;
    emit OraclesAdded(keyHashes, oracleAddrs);
  }

  /**
   * @dev Removes information about multiple oracles and emits an event.
   * @param keyHashes The key hashes of the oracles to be removed.
   */
  function _removeOracleSet(bytes32[] calldata keyHashes) internal {
    uint256 index;
    address oracleAddr;

    for (uint256 i; i < keyHashes.length; ++i) {
      // key hash to remove should not be null
      if (keyHashes[i] == bytes32(0x0)) revert NullValue(i);
      // key hash to remove should exist in storage before
      if ((oracleAddr = getOracleInfo(keyHashes[i]).oracleAddr) == address(0x0)) {
        revert UnexistedKeyHash(keyHashes[i]);
      }

      // update `_keyHashes` set
      delete _record.keyHashes[index];

      // update `_oracleInfo` mapping
      _oracleInfo[keyHashes[i]].oracleAddr = address(0x0);
      _oracleInfo[keyHashes[i]].infoUpdatedAtBlock = block.number;

      // update `_keyHashOf` mapping
      _keyHashOf[oracleAddr] = bytes32(0x0);

      // update `stat` mapping
      delete _record.stat[keyHashes[i]];
    }

    _record.keyHashCount -= keyHashes.length;
    emit OraclesRemoved(keyHashes);
  }

  /**
   * @dev Checks if the provided array is not empty.
   * @param arr The array to check.
   */
  function _requireNonEmptyArray(bytes32[] calldata arr) internal pure {
    if (arr.length == 0) revert InvalidArrayLength();
  }

  function _reorderKeyHashesByScore() internal view returns (bytes32[] memory reordered) {
    bytes32[] memory allKeyHashes = getAllKeyHashes();
    uint256[] memory scores = new uint256[](allKeyHashes.length);

    for (uint256 i; i < scores.length; ++i) {
      scores[i] = _record.stat[allKeyHashes[i]].score;
    }

    reordered = allKeyHashes.toUint256s().inlineQuickSortByValue({ values: scores }).toBytes32s();
  }
}
