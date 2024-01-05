// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { LibArray } from "./LibArray.sol";
import { SafeCast, Period } from "./LibPeriod.sol";

struct Config {
  /// @dev Slot: 0
  FulfillSetting forFulfill;
  /// @dev Slot: 1
  AssignSetting forAssign;
  /// @dev Slot: 2
  uint256 maxResponseBlock;
  /// @dev Slot: 3
  uint256 periodDuration;
}

/**
 * @dev Represents statistics of an operator.
 * @param score The score of the current operator.
 * @param assignedCount The number of times the operator is assigned for fulfillRandomSeed.
 * @param fulFilledCount The number of times the operator fulfilled the request.
 */
struct Stat {
  uint64 score;
  uint64 assignCount;
  uint64 fulfillCount;
  uint64 _reservedInner;
}

struct AssignSetting {
  uint8 score;
  uint248 _reservedInner;
}

struct FulfillSetting {
  uint8 lower;
  uint8 upper;
  uint8 blockInterval;
  uint232 _reservedInner;
}

struct Record {
  /// @dev Slot: 0
  uint256 keyHashCount;
  /// @dev Slot: 1
  Period period;
  /// @dev Slot: 2
  bytes32[] keyHashes;
  /// @dev Slot: 3
  mapping(bytes32 keyHash => Stat stat) stat;
  /// @dev Slot: 4
  mapping(uint256 period => uint256 cummulativeScore) sumScore;
}

using LibStatTracking for Record global;

/**
 * @title LibStatTracking
 * @dev A library for tracking and updating statistics of operators.
 */
library LibStatTracking {
  using SafeCast for *;
  using LibArray for *;

  event AllScoresSynced(
    address indexed by, uint128 indexed period, uint256 avgScoreDecreased, bytes32[] keyHashes, uint256[] scores
  );

  modifier whenOperatorScoreChange(Record storage record, bytes32 keyHash) {
    uint256 scoreBefore = record.stat[keyHash].score;
    _;
    updateSumScoreOnChange({ keyHash: keyHash, scoreBefore: scoreBefore, record: record });
  }

  function handleRequest(Record storage record, Config storage cfg) internal returns (bytes32[] memory orderedSet) {
    (bytes32[] memory keyHashes, uint256[] memory scores) = trackPeriodChangeAndSyncStats({ record: record, cfg: cfg });
    orderedSet = keyHashes.toUint256s().inlineQuickSortByValue({ values: scores }).toBytes32s();
    updateOperatorScoreWhenAssign({ record: record, assignee: orderedSet[0], config: cfg });
  }

  function handleFulfill(
    Record storage record,
    bytes32 fulfiller,
    Config memory cfg,
    uint256 fulfillOrder,
    uint256 blockElapsed
  ) internal {
    record.trackPeriodChangeAndSyncStats({ cfg: cfg });
    updateOperatorScoreWhenFulfill(record, fulfiller, cfg, fulfillOrder, blockElapsed);
  }

  function updateOperatorScoreWhenAssign(Record storage record, bytes32 assignee, Config memory config)
    private
    whenOperatorScoreChange(record, assignee)
  {
    unchecked {
      Stat storage stat = record.stat[assignee];
      stat.score += config.forAssign.score;
      ++stat.assignCount;
    }
  }

  function updateOperatorScoreWhenFulfill(
    Record storage record,
    bytes32 fulfiller,
    Config memory cfg,
    uint256 fulfillOrder,
    uint256 blockElapsed
  ) private whenOperatorScoreChange(record, fulfiller) {
    unchecked {
      Stat storage stat = record.stat[fulfiller];
      uint256 scoreChange = cfg.forFulfill.lower;

      if (fulfillOrder == 0) {
        scoreChange += (cfg.maxResponseBlock - blockElapsed) / cfg.forFulfill.blockInterval;
        stat.score -= Math.min(cfg.forFulfill.upper, scoreChange).toUint64();
      } else {
        stat.score += scoreChange.toUint64();
      }
      ++stat.fulfillCount;
    }
  }

  function updateSumScoreOnChange(bytes32 keyHash, uint256 scoreBefore, Record storage record) private {
    unchecked {
      uint256 currentPeriod = record.period.current();
      uint256 scoreNow = record.stat[keyHash].score;

      if (scoreNow > scoreBefore) {
        record.sumScore[currentPeriod] += scoreNow - scoreBefore;
      } else if (scoreNow < scoreBefore) {
        record.sumScore[currentPeriod] -= scoreBefore - scoreNow;
      }
    }
  }

  function trackPeriodChangeAndSyncStats(Record storage record, Config memory cfg)
    internal
    returns (bytes32[] memory keyHashes, uint256[] memory scores)
  {
    unchecked {
      uint128 lastTrackedPeriod = record.period.current();
      (bool updated, uint128 currentPeriod) =
        record.period.tryUpdate({ currentTimestamp: block.number, periodDuration: cfg.periodDuration });

      return updated == false
        ? record.getKeyHashesAndScores()
        : syncScores({ record: record, prevPeriod: lastTrackedPeriod, currentPeriod: currentPeriod });
    }
  }

  function syncScores(Record storage record, uint128 prevPeriod, uint128 currentPeriod)
    private
    returns (bytes32[] memory keyHashes, uint256[] memory scores)
  {
    unchecked {
      uint256 sumScoreForCurrentPeriod;
      uint256 length = record.keyHashes.length;
      if (length <= 1) return (keyHashes, scores);
      uint64 prevPeriodAverage = (record.sumScore[prevPeriod] / record.keyHashCount).toUint64();

      uint256 count;
      scores = new uint256[](length);
      keyHashes = new bytes32[](length);

      for (uint256 i; i < length; ++i) {
        bytes32 keyHash = record.keyHashes[i];
        Stat storage stat = record.stat[keyHash];

        if (keyHash != bytes32(0x0)) {
          uint64 score = stat.score;

          if (score > prevPeriodAverage) {
            score -= prevPeriodAverage;
            sumScoreForCurrentPeriod += score;
            stat.score = score;
          } else {
            delete record.stat[keyHash].score;
          }

          scores[count] = score;
          keyHashes[count] = keyHash;
          ++count;
        }
      }

      assembly ("memory-safe") {
        mstore(scores, count)
        mstore(keyHashes, count)
      }

      record.sumScore[currentPeriod] = sumScoreForCurrentPeriod;

      emit AllScoresSynced(msg.sender, currentPeriod, prevPeriodAverage, keyHashes, scores);
    }
  }

  function getAllKeyHashes(Record storage record) internal view returns (bytes32[] memory keyHashes) {
    uint256 length = record.keyHashes.length;
    if (length <= 1) return keyHashes;
    keyHashes = new bytes32[](length);
    uint256 count;
    bytes32 keyHash;

    for (uint256 i; i < length; ++i) {
      keyHash = record.keyHashes[i];
      unchecked {
        if (keyHash != bytes32(0x0)) keyHashes[count++] = keyHash;
      }
    }

    // resize array
    assembly ("memory-safe") {
      mstore(keyHashes, count)
    }
  }

  function getKeyHashesAndScores(Record storage record)
    internal
    view
    returns (bytes32[] memory keyHashes, uint256[] memory scores)
  {
    uint256 length = record.keyHashes.length;
    if (length <= 1) return (keyHashes, scores);

    scores = new uint256[](length);
    keyHashes = new bytes32[](length);

    uint256 count;
    uint64 score;
    bytes32 keyHash;

    for (uint256 i; i < length; ++i) {
      keyHash = record.keyHashes[i];
      unchecked {
        if (keyHash != bytes32(0x0)) {
          score = record.stat[keyHash].score;

          scores[count] = score;
          keyHashes[count] = keyHash;
          ++count;
        }
      }
    }

    // resize array
    assembly ("memory-safe") {
      mstore(scores, count)
      mstore(keyHashes, count)
    }
  }
}
