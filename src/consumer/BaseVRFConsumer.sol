// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IBaseVRFConsumer } from "../interfaces/consumers/IBaseVRFConsumer.sol";
import { IRoninVRFCoordinatorForConsumers } from "../interfaces/coordinators/IRoninVRFCoordinatorForConsumers.sol";

abstract contract BaseVRFConsumer is IBaseVRFConsumer {
  /// @dev address of VRFCoordinator contract
  address internal _vrfCoordinator;

  /**
   * @inheritdoc IBaseVRFConsumer
   */
  function vrfCoordinator() public view returns (address) {
    return _vrfCoordinator;
  }

  /**
   * @inheritdoc IBaseVRFConsumer
   */
  function rawFulfillRandomSeed(bytes32 reqHash, uint256 randomSeed) external {
    if (msg.sender != _vrfCoordinator) revert OnlyCoordinatorCanFulfill();
    _fulfillRandomSeed(reqHash, randomSeed);
  }

  /**
   * @dev Sets the address of the VRF Coordinator.
   * @param coor The address of the VRF Coordinator contract.
   */
  function _setVrfCoordinator(address coor) internal {
    _vrfCoordinator = coor;
    emit VRFCoordinatorAddressUpdated(coor);
  }

  /**
   * @dev Fulfills random seed `randomSeed` based on the request hash `reqHash`
   */
  function _fulfillRandomSeed(bytes32 reqHash, uint256 randomSeed) internal virtual;

  /**
   * @dev Request random seed to the coordinator contract. Returns the request hash.
   *  Consider using the method `IRoninVRFCoordinatorForConsumers.estimateRequestRandomFee` to estimate the random fee.
   *
   * @param value Amount of RON to cover gas fee for oracle, will be refunded to `refundAddr`.
   * @param callbackGasLimit The callback gas amount, which should cover enough gas used for the method `_fulfillRandomSeed`.
   * @param gasPriceToFulFill The gas price that orale must send transaction to fulfill.
   * @param refundAddr Refund address if there is RON left after paying gas fee to oracle.
   */
  function _requestRandomness(uint256 value, uint256 callbackGasLimit, uint256 gasPriceToFulFill, address refundAddr)
    internal
    virtual
    returns (bytes32 reqHash)
  {
    reqHash = IRoninVRFCoordinatorForConsumers(_vrfCoordinator).requestRandomSeed{ value: value }({
      callbackGasLimit: callbackGasLimit,
      gasPrice: gasPriceToFulFill,
      consumer: address(this),
      refundAddress: refundAddr
    });
  }
}
