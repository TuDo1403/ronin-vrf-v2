// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { SafeCast, Period } from "./LibPeriod.sol";

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
  uint64 lastUpdatedAtPeriod;
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
  mapping(uint256 period => uint256 sumScoreEachPeriod) sumScore;
}

struct Config {
  /// @dev Slot: 0
  FulfillConfig forFulfill;
  /// @dev Slot: 1
  AssignConfig forAssign;
  /// @dev Slot: 2
  uint256 maxResponseBlock;
  /// @dev Slot: 3
  uint256 periodDuration;
}

struct AssignConfig {
  uint8 score;
  uint248 _reservedInner;
}

struct FulfillConfig {
  uint8 lower;
  uint8 upper;
  uint8 blockInterval;
  uint232 _reservedInner;
}

/**
 * @title LibStatTracking
 * @dev A library for tracking and updating statistics of operators.
 */
library LibStatTracking {
  using SafeCast for *;

  modifier trackPeriodAndUpdateStat(bytes32 keyHash, Record storage record, Config storage cfg) {
    beforeOperatorStatUpdated(keyHash, record, cfg);
    _;
  }

  function beforeOperatorStatUpdated(bytes32 keyHash, Record storage record, Config storage cfg) private {
    unchecked {
      (bool updated, uint256 currentPeriod) =
        record.period.tryUpdate({ current: block.number, periodDuration: cfg.periodDuration });

      

      if (updated) {
        uint256 lastUpdatedAtPeriod = record.stat[keyHash].lastUpdatedAtPeriod;
        uint256 keyHashCount = record.keyHashCount;

        decreaseOperatorScoresByAverage({ record: record, prevPeriod: currentPeriod - 1 });
      } else {
        
      }
    }
  }

  /**
   * @dev Decrease operator scores by the average of the last period.
   * @param record Global operator statistics.
   * @param prevPeriod The previous period.
   */
  function decreaseOperatorScoresByAverage(Record storage record, uint256 prevPeriod) private {
    unchecked {
      uint64 score;
      bytes32 keyHash;
      uint256 length = record.keyHashes.length;
      uint64 lastPeriodAverage = (record.sumScore[prevPeriod] / record.keyHashCount).toUint64();

      for (uint256 i; i < length; ++i) {
        keyHash = record.keyHashes[i];
        if (keyHash != bytes32(0x0)) {
          score = record.stat[keyHash].score;
          if (score > lastPeriodAverage) {
            record.stat[keyHash].score = score - lastPeriodAverage;
          }
        }
      }
    }
  }

  function onAssigned(bytes32 keyHash, Record storage record, Config storage cfg)
    internal
    trackPeriodAndUpdateStat(keyHash, record, cfg)
  {
    unchecked {
      Stat storage operatorStat = record.stat[keyHash];

      operatorStat.score += cfg.forAssign.score;
      ++operatorStat.assignCount;
      operatorStat.lastUpdatedAtPeriod = record.period.current().toUint64();
    }
  }

  function onFulfilled(
    bytes32 keyHash,
    Record storage record,
    Config storage cfg,
    uint256 fulfillOrder,
    uint256 blockElapsed
  ) internal trackPeriodAndUpdateStat(keyHash, record, cfg) {
    unchecked {
      FulfillConfig memory fulfillCfg = cfg.forFulfill;
      Stat storage operatorStat = record.stat[keyHash];

      if (fulfillOrder == 0) {
        uint256 scoreToDecrease = (cfg.maxResponseBlock - blockElapsed) / fulfillCfg.blockInterval + fulfillCfg.lower;
        operatorStat.score -= Math.min(fulfillCfg.upper, scoreToDecrease).toUint64();
      } else {
        operatorStat.score += fulfillCfg.lower;
      }
      ++operatorStat.fulfillCount;
      operatorStat.lastUpdatedAtPeriod = record.period.current().toUint64();
    }
  }
}
