// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IRoninVRFCoordinatorForConsumers {
  /**
   * @dev Request random seed to the coordinator contract. Returns the request hash.
   *  Consider using the method `estimateRequestRandomFee` to estimate the random fee.
   *
   * @param callbackGasLimit The callback gas amount.
   * @param gasPrice The gas price that orale must send transaction to fulfill.
   * @param consumer The consumer address to callback.
   * @param refundAddress Refund address if there is RON left after paying gas fee to oracle.
   */
  function requestRandomSeed(uint256 callbackGasLimit, uint256 gasPrice, address consumer, address refundAddress)
    external
    payable
    returns (bytes32 reqHash);

  /**
   * @dev Estimates the request random fee in RON.
   *
   * @notice It should be larger than the real cost and the contract will refund if any.
   */
  function estimateRequestRandomFee(uint256 callbackGasLimit, uint256 gasPrice) external view returns (uint256 fee);
}
