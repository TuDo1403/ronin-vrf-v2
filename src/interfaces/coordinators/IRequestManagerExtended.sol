// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { IRequestManager } from "./IRequestManager.sol";

interface IRequestManagerExtended is IRequestManager {
  struct RequestStatus {
    address finalizedBy;
    address assignedTo;
    bytes32[] keyHashesByOrder;
  }

  function requestFinalizedBy(bytes32 reqHash) external view returns (address finalizedBy);

  function requestFulfillOrder(bytes32 reqHash) external view returns (bytes32[] memory keyHashesByOrder);
}
