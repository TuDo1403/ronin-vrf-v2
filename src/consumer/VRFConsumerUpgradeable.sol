// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import { BaseVRFConsumer } from "./BaseVRFConsumer.sol";

abstract contract VRFConsumerUpgradeable is Initializable, BaseVRFConsumer {
  /**
   * @param vrfCoordinator_ address of VRFCoordinator contract
   */
  function __VRFConsumerUpgradeable_init_unchained(address vrfCoordinator_) internal onlyInitializing {
    _setVrfCoordinator(vrfCoordinator_);
  }
}
