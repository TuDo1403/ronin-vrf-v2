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
  event PeriodUpdated(address indexed by, uint256 indexed currentPeriod, uint256 lastUpdatedAt);

  function current(Period storage period) internal view returns (uint256) {
    return period._currentPeriod;
  }

  /**
   * @dev Tries to update the current period based on the provided timestamp.
   * @param period The storage reference to the Period struct.
   * @param current The current timestamp.
   * @param periodDuration The duration of each period.
   * @return updated True if the period was successfully updated, false otherwise.
   * @return currentPeriod The updated current period.
   */
  function tryUpdate(Period storage period, uint256 current, uint256 periodDuration)
    internal
    returns (bool updated, uint256 currentPeriod)
  {
    unchecked {
      currentPeriod = period._currentPeriod;
      uint256 lastUpdatedAt = period._lastUpdatedAt;
      if (current < lastUpdatedAt + periodDuration) return (false, currentPeriod);

      period._lastUpdatedAt = current.toUint128();
      currentPeriod = (current - lastUpdatedAt) / periodDuration;
      period._currentPeriod = currentPeriod.toUint128();
      emit PeriodUpdated(msg.sender, currentPeriod, current);

      return (true, currentPeriod);
    }
  }
}
