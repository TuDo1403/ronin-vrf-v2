// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library LibSLA {
  struct RandomRequest {
    uint256 blockNumber;
    uint256 callbackGasLimit;
    uint256 gasPrice;
    uint256 gasFee;
    address requester;
    address consumer;
    address refundAddr;
    uint256 nonce;
    uint256 constantFee;
  }

  /**
   * @dev Returns the struct hash.
   */
  function hash(RandomRequest memory request) internal pure returns (bytes32) {
    return keccak256(
      abi.encode(
        request.blockNumber,
        request.callbackGasLimit,
        request.gasPrice,
        request.gasFee,
        request.requester,
        request.consumer,
        request.refundAddr,
        request.nonce,
        request.constantFee
      )
    );
  }

  /**
   * @dev Returns the proof seed from random request.
   */
  function calcProofSeed(RandomRequest memory request, bytes32 keyHash, address oracle) internal pure returns (uint256) {
    return uint256(
      keccak256(
        abi.encode(
          request.blockNumber,
          request.callbackGasLimit,
          request.gasPrice,
          request.gasFee,
          request.requester,
          request.consumer,
          request.nonce,
          request.constantFee,
          keyHash,
          oracle
        )
      )
    );
  }
}
