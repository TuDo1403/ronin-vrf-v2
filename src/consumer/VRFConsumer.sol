// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { BaseVRFConsumer } from "./BaseVRFConsumer.sol";

abstract contract VRFConsumer is BaseVRFConsumer {
  constructor(address vrfCoordinator_) {
    _setVrfCoordinator(vrfCoordinator_);
  }
}
