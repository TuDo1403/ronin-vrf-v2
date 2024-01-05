// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { VRF } from "@chainlink/contracts/src/v0.8/VRF.sol";
import { LibSLA } from "../../libraries/LibSLA.sol";
import { IRoninVRFCoordinatorForConsumers } from "./IRoninVRFCoordinatorForConsumers.sol";

interface IRoninVRFCoordinator is IRoninVRFCoordinatorForConsumers {
  /// @dev Throwed when the random request to fulfill is wrong compared with the requested.
  error WrongRandomRequest();
  /// @dev Throwed when the random request is already finalized.
  error RandomRequestAlreadyFinalized();
  /// @dev Throwed when the method caller is invalid.
  error InvalidSender(address expectedSender);
  /// @dev Throwed when the price gas is invalid.
  error InvalidGasPrice();
  /// @dev Throwed when the gas fee is insufficient.
  error InsufficientFee();
  /// @dev Throwed when the proof seed is invalid.
  error InvalidProofSeed();
  /// @dev Throwed when the refund address can not receive RON.
  error InvalidRefundAddress(address);
  /// @dev Throwed when the caller of request random seed is not match with consumer address.
  error CallerIsNotAConsumer();
  error RequestTimeOut();
  error InvalidFulfillOrder(bytes32 expectedKeyHash);

  /**
   * @dev Emitted when a random seed is requested.
   * @param reqHash The hash of the random seed request.
   * @param request The details of the random seed request.
   * @param keyHashesByOrder The ordered keys used for fulfill request.
   */
  event RandomSeedRequested(bytes32 indexed reqHash, LibSLA.RandomRequest request, bytes32[] keyHashesByOrder);
  /// @dev Emitted when the random seed are fulfilled.
  event RandomSeedFulfilled(
    bytes32 indexed requestHash,
    uint256 randomSeed,
    uint256 requestValue,
    uint256 refundAmount,
    uint256 paymentAmount,
    uint256 constantFee,
    bool callbackResult
  );
  /// @dev Emitted when the gas cost for payment calculation is updated.
  event GasAfterPaymentCalculationUpdated(uint256 gasCost);
  /// @dev Emitted when the gas cost to estimate random fee is updated.
  event GasToEstimateRandomFeeUpdated(uint256 gasCost);
  /// @dev Emitted when the treasury address is updated.
  event TreasuryUpdated(address treasury);
  /// @dev Emitted when the constant fee is updated.
  event ConstantFeeUpdated(uint256 constantFee);

  /**
   * @dev Fulfills random seed based on the request randomness `req`.
   *
   * Requirements:
   * - The method caller is oracle.
   * - The transaction gas price must be equal to the gas price in request randomness.
   * - The random request is not finalized yet.
   * - The refund address is able to receive RON.
   *
   * Emits the `RandomSeedFulfilled` event.
   *
   */
  function fulfillRandomSeed(VRF.Proof memory proof, LibSLA.RandomRequest memory req)
    external
    returns (uint256 paymentAmount);

  /**
   * @dev See `_setTreasury`.
   *
   * Requirements:
   * - The caller must be the owner.
   */
  function setTreasury(address treasury) external;

  /**
   * @dev Sets the constant fee.
   *
   * Emits the `ConstantFeeUpdated` event.
   *
   * Requirements:
   * - The caller must be the owner.
   */
  function setConstantFee(uint256 constantFee) external;

  /**
   * @dev Sets the gas cost for payment calculation.
   *
   * Emits the `GasAfterPaymentCalculationUpdated` event.
   *
   * Requiments:
   * - The method caller is the contract admin.
   *
   */
  function setGasToEstimateRandomFee(uint256 gas) external;

  /**
   * @dev Sets the gas cost for payment calculation.
   *
   * Emits the `GasAfterPaymentCalculationUpdated` event.
   *
   * Requiments:
   * - The method caller is the contract admin.
   *
   */
  function setGasAfterPaymentCalculation(uint256 gas) external;

  /**
   * @dev Returns the proving key hash key associated with this public key.
   */
  function keyHash(uint256[2] memory publicKey) external pure returns (bytes32);

  /**
   * @dev Returns the address to receive the constant fee for each req randomness.
   */
  function treasury() external view returns (address);

  /**
   * @dev Returns the number of RON charges for each req randomness.
   */
  function constantFee() external view returns (uint256);

  /**
   * @dev Returns the gas cost for payment calculation, transfer funds and emits event in the method `fulfillRandomSeed`.
   */
  function gasAfterPaymentCalculation() external view returns (uint256);

  /**
   * @dev Returns the gas cost to estimate random fee. Its value should include: the gas cost before triggerring the
   * `_callWithExactGas`, VRF gas cost and gas cost after payment caculation.
   */
  function gasToEstimateRandomFee() external view returns (uint256);
}
