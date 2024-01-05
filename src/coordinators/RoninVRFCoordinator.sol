// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { StorageSlot, RequestManager } from "./RequestManager.sol";
import { OracleManager } from "./OracleManager.sol";
import { WhitelistConsumer } from "../whitelist/WhitelistConsumer.sol";
import {
  VRF,
  IRoninVRFCoordinator,
  IRoninVRFCoordinatorForConsumers
} from "../interfaces/coordinators/IRoninVRFCoordinator.sol";
import { IBaseVRFConsumer } from "../interfaces/consumers/IBaseVRFConsumer.sol";
import { LibStatTracking } from "../libraries/LibStatTracking.sol";
import { LibNativeTransfer } from "contract-libs/transfers/LibNativeTransfer.sol";
import { LibSLA } from "../libraries/LibSLA.sol";
import { LibSafeCall } from "../libraries/LibSafeCall.sol";

contract RoninVRFCoordinator is
  Initializable,
  VRF,
  Ownable,
  RequestManager,
  OracleManager,
  WhitelistConsumer,
  IRoninVRFCoordinator
{
  using LibSafeCall for address;
  using StorageSlot for bytes32;
  using LibStatTracking for bytes32;
  using LibSLA for LibSLA.RandomRequest;

  /**
   * @dev The addition amount of gas sending along in external calls.
   * Total gas stipend is added with default 2300 gas for positive RON amount.
   */
  uint256 private constant DEFAULT_ADDITION_GAS = 1200;

  /**
   * @dev The minimum gas price required in requesting randomness.
   */
  uint256 private constant MINIMUM_GAS_PRICE = 20e9; // 20 Gwei

  /// @dev See {IRoninVRFCoordinator-gasToEstimateRandomFee}
  uint256 internal _gasToEstimateRandomFee;
  /// @dev See {IRoninVRFCoordinator-gasAfterPaymentCalculation}
  uint256 internal _gasAfterPaymentCalculation;
  /// @dev See {IRoninVRFCoordinator-treasury}
  address internal _treasury;
  /// @dev See {IRoninVRFCoordinator-constantFee}
  uint256 internal _constantFee;

  modifier lock() {
    _requireNotLocked();
    $_LOCK_STORAGE.getBooleanSlot().value = true;
    _;
    $_LOCK_STORAGE.getBooleanSlot().value = false;
  }

  /**
   * @dev Initalizes the contract storage.
   */
  function initialize(
    address admin,
    uint256 gasToEstimateRandomFee_,
    uint256 gasAfterPaymentCalculation_,
    uint256 constantFee_,
    address treasury_
  ) external initializer {
    _transferOwnership(admin);
    _setGasToEstimateRandomFee(gasToEstimateRandomFee_);
    _setGasAfterPaymentCalculation(gasAfterPaymentCalculation_);
    _setConstantFee(constantFee_);
    _setTreasury(treasury_);
  }

  function initializeV2(uint256 periodDuration, uint256 maxResponseBlock) external reinitializer(2) {
    __OracleManager_init_unchained(periodDuration, maxResponseBlock);
  }

  /**
   * @inheritdoc IRoninVRFCoordinator
   */
  function setTreasury(address treasury_) external onlyOwner {
    _setTreasury(treasury_);
  }

  /**
   * @inheritdoc IRoninVRFCoordinator
   */
  function setConstantFee(uint256 constantFee_) external onlyOwner {
    _setConstantFee(constantFee_);
  }

  /**
   * @inheritdoc IRoninVRFCoordinator
   */
  function setGasToEstimateRandomFee(uint256 gas) external onlyOwner {
    _setGasToEstimateRandomFee(gas);
  }

  /**
   * @inheritdoc IRoninVRFCoordinator
   */
  function setGasAfterPaymentCalculation(uint256 gas) external onlyOwner {
    _setGasAfterPaymentCalculation(gas);
  }

  /**
   * @inheritdoc IRoninVRFCoordinatorForConsumers
   */
  function requestRandomSeed(uint256 callbackGasLimit, uint256 gasPrice, address consumer, address refundAddress)
    external
    payable
    onlyWhitelisted(consumer)
    returns (bytes32 reqHash)
  {
    address sender = _msgSender();
    if (sender != consumer) revert CallerIsNotAConsumer();
    if (gasPrice < MINIMUM_GAS_PRICE) revert InvalidGasPrice();
    uint256 nonce = _requestNonce[consumer]++;
    LibSLA.RandomRequest memory req = LibSLA.RandomRequest({
      blockNumber: block.number,
      callbackGasLimit: callbackGasLimit,
      gasPrice: gasPrice,
      gasFee: msg.value,
      requester: sender,
      consumer: consumer,
      refundAddr: refundAddress,
      nonce: nonce,
      constantFee: _constantFee
    });
    if (estimateRequestRandomFee(callbackGasLimit, gasPrice) > msg.value) revert InsufficientFee();

    reqHash = req.hash();
    bytes32[] memory keyHashesByOrder = _reorderKeyHashesByScore();

    _requestHash[consumer][nonce] = reqHash;
    _requestStatus[reqHash].keyHashesByOrder = keyHashesByOrder;
    keyHashesByOrder[0].onAssigned({ record: _record, cfg: _config });

    emit RandomSeedRequested(reqHash, req, keyHashesByOrder);
  }

  /**
   * @inheritdoc IRoninVRFCoordinator
   */
  function fulfillRandomSeed(Proof calldata proof, LibSLA.RandomRequest calldata req)
    external
    lock
    returns (uint256 paymentAmount)
  {
    uint256 gas = gasleft();

    if (req.gasPrice != tx.gasprice) revert InvalidGasPrice();

    bytes32 reqHash = req.hash();
    if (_requestHash[req.consumer][req.nonce] != reqHash) revert WrongRandomRequest();
    if (_requestStatus[reqHash].finalizedBy != address(0x0)) revert RandomRequestAlreadyFinalized();

    uint256 numBlockSinceRequest = block.number - req.blockNumber;
    uint256 idx = numBlockSinceRequest / getMaxResponseBlock();
    if (idx >= _requestStatus[reqHash].keyHashesByOrder.length) revert RequestTimeOut();

    bytes32 keyhash = _requestStatus[reqHash].keyHashesByOrder[idx];
    address oracle = _oracleInfo[keyhash].oracleAddr;
    if (_msgSender() != oracle) revert InvalidSender(oracle);
    if (keyhash != keyHash(proof.pk)) revert InvalidFulfillOrder(keyhash);
    if (req.calcProofSeed(keyhash, oracle) != proof.seed) revert InvalidProofSeed();

    // Update oracles and request data before transfer.
    _requestStatus[reqHash].finalizedBy = oracle;
    keyhash.onFulfilled({ cfg: _config, record: _record, fulfillOrder: idx, blockElapsed: numBlockSinceRequest });

    // Verifies the proof and generates random seed. Reverts on failure.
    uint256 randomSeed = VRF.randomValueFromVRFProof(proof, proof.seed);

    // Vefifies success, takes fee for treasury.
    LibNativeTransfer.transfer(_treasury, req.constantFee, DEFAULT_ADDITION_GAS);

    // Callbacks to consumer and calculates the payment amount.
    bool success = req.consumer.callWithExactGas({
      data: abi.encodeCall(IBaseVRFConsumer.rawFulfillRandomSeed, (reqHash, randomSeed)),
      gasAmount: req.callbackGasLimit
    });

    paymentAmount = _calculatePaymentAmount(gas, req.gasPrice);
    if (req.gasFee <= paymentAmount + req.constantFee) revert InsufficientFee();
    LibNativeTransfer.transfer(oracle, paymentAmount, DEFAULT_ADDITION_GAS);

    uint256 refundAmount = req.gasFee - paymentAmount - req.constantFee;
    if (refundAmount != 0) LibNativeTransfer.transfer(req.refundAddr, refundAmount, DEFAULT_ADDITION_GAS);

    emit RandomSeedFulfilled(reqHash, randomSeed, req.gasFee, refundAmount, paymentAmount, _constantFee, success);
  }

  /**
   * @inheritdoc IRoninVRFCoordinatorForConsumers
   */
  function estimateRequestRandomFee(uint256 callbackGasLimit, uint256 gasPrice) public view returns (uint256) {
    return (_gasToEstimateRandomFee + callbackGasLimit) * gasPrice + _constantFee;
  }

  /**
   * @inheritdoc IRoninVRFCoordinator
   */
  function keyHash(uint256[2] memory publicKey) public pure returns (bytes32) {
    return keccak256(abi.encode(publicKey));
  }

  /**
   * @inheritdoc IRoninVRFCoordinator
   */
  function treasury() public view returns (address) {
    return _treasury;
  }

  /**
   * @inheritdoc IRoninVRFCoordinator
   */
  function constantFee() public view returns (uint256) {
    return _constantFee;
  }

  /**
   * @inheritdoc IRoninVRFCoordinator
   */
  function gasAfterPaymentCalculation() public view returns (uint256) {
    return _gasAfterPaymentCalculation;
  }

  /**
   * @inheritdoc IRoninVRFCoordinator
   */
  function gasToEstimateRandomFee() public view returns (uint256) {
    return _gasToEstimateRandomFee;
  }

  /**
   * @dev Sets the gas cost to estimate random fee.
   *
   * Emits the `GasToEstimateRandomFeeUpdated` event.
   *
   */
  function _setGasToEstimateRandomFee(uint256 gas) internal {
    _gasToEstimateRandomFee = gas;
    emit GasToEstimateRandomFeeUpdated(gas);
  }

  /**
   * @dev Sets the gas cost for payment calculation.
   *
   * Emits the `GasAfterPaymentCalculationUpdated` event.
   *
   */
  function _setGasAfterPaymentCalculation(uint256 gas) internal {
    _gasAfterPaymentCalculation = gas;
    emit GasAfterPaymentCalculationUpdated(gas);
  }

  /**
   * @dev Sets the treasury address.
   *
   * Emits the `TreasuryUpdated` event.
   *
   */
  function _setTreasury(address treasury_) internal {
    _treasury = treasury_;
    emit TreasuryUpdated(treasury_);
  }

  /**
   * @dev Sets the constant fee.
   *
   * Emits the `ConstantFeeUpdated` event.
   */
  function _setConstantFee(uint256 constantFee_) internal {
    _constantFee = constantFee_;
    emit ConstantFeeUpdated(constantFee_);
  }

  /**
   * @dev Calculates the payment amount.
   */
  function _calculatePaymentAmount(uint256 originGasAmount, uint256 gasPrice) internal view returns (uint256) {
    return (_gasAfterPaymentCalculation + originGasAmount - gasleft()) * gasPrice;
  }
}
