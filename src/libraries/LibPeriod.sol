// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";

/**
 * @dev Period struct representing a period and the timestamp when it was last updated.
 */
struct Period {
  uint128 _currentPeriod;
  uint128 _lastUpdatedAt;
}

using LibPeriod for Period global;

/**
 * @title LibPeriod
 * @dev A library for managing periods with a specified duration.
 */
library LibPeriod {
  using SafeCast for uint256;

  /**
   * @dev Emitted when a period is successfully updated.
   * @param by The address triggering the update.
   * @param currentPeriod The updated current period.
   * @param lastUpdatedAt The timestamp when the period was last updated.
   */
  event NewPeriod(address indexed by, uint128 indexed currentPeriod, uint128 lastUpdatedAt);

  function current(Period storage period) internal view returns (uint128) {
    return period._currentPeriod;
  }

  function updatedAt(Period storage period) internal view returns (uint128) {
    return period._lastUpdatedAt;
  }

  function nextPeriodStartAt(Period storage period, uint256 periodDuration) internal view returns (uint256) {
    return updatedAt(period) + periodDuration;
  }

  /**
   * @dev Tries to update the current period based on the provided timestamp.
   * @param period The storage reference to the Period struct.
   * @param currentTimestamp The current timestamp.
   * @param periodDuration The duration of each period.
   * @return updated True if the period was successfully updated, false otherwise.
   * @return currentPeriod The updated current period.
   */
  function tryUpdate(Period storage period, uint256 currentTimestamp, uint256 periodDuration)
    internal
    returns (bool updated, uint128 currentPeriod)
  {
    unchecked {
      currentPeriod = current(period);
      uint128 lastUpdatedAt = updatedAt(period);
      if (currentTimestamp < lastUpdatedAt + periodDuration) return (false, currentPeriod);
      currentPeriod += ((currentTimestamp - lastUpdatedAt) / periodDuration).toUint128();

      period._currentPeriod = currentPeriod;
      period._lastUpdatedAt = currentTimestamp.toUint128();
      emit NewPeriod(msg.sender, currentPeriod, currentTimestamp.toUint128());

      return (true, currentPeriod);
    }
  }
}
