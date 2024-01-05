// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IBaseVRFConsumer {
  /**
   * @dev Error indicating that only the VRF Coordinator is allowed to fulfill random seeds.
   */
  error OnlyCoordinatorCanFulfill();

  /**
   * @dev Emitted when the VRF Coordinator address is updated.
   * @param newCoordinator The new address of the VRF Coordinator.
   */
  event VRFCoordinatorAddressUpdated(address indexed newCoordinator);

  /**
   * @dev Raw fulfills random seed.
   *
   * Requirements:
   * - The method caller is VRF coordinator `vrfCoordinator`.
   *
   * @notice The function `rawFulfillRandomSeed` is called by VRFCoordinator when it receives a valid VRF
   * proof. It then calls `_fulfillRandomSeed`, after validating the origin of the call.
   *
   */
  function rawFulfillRandomSeed(bytes32 reqHash, uint256 randomSeed) external;

  /**
   * @dev Get VRF coordinator contract
   */
  function vrfCoordinator() external view returns (address);
}
