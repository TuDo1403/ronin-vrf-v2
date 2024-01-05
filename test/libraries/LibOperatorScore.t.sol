// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { Test, console2 as console } from "forge-std/Test.sol";

contract LibOperatorScoreTest is Test {
  function testScoreCalculation(uint8 numBlockSinceRequest) external {
    unchecked {
      uint256 maxScoreDecrease = 4;
      uint256 minScoreDecrease = 1;
      uint256 maxResponseBlock = 22;
      uint256 blockInterval = 5;

      // Ensure numBlockSinceRequest is within the range [0, maxResponseBlock]
      uint256 boundedNumBlocks = uint8(bound(numBlockSinceRequest, 0, maxResponseBlock));

      // Calculate the score change based on the bounded numBlockSinceRequest
      uint256 scoreChange =
        Math.min(maxScoreDecrease, (maxResponseBlock - boundedNumBlocks) / blockInterval + minScoreDecrease);

      // Log information for debugging or verification
      console.log("num block", boundedNumBlocks);
      console.log("score change", scoreChange);

      // Assert statements to verify the correctness of scoreChange calculations
      if (boundedNumBlocks <= 7) assertEq(scoreChange, 4);
      else if (boundedNumBlocks <= 12) assertEq(scoreChange, 3);
      else if (boundedNumBlocks <= 17) assertEq(scoreChange, 2);
      else if (boundedNumBlocks <= 22) assertEq(scoreChange, 1);
    }
  }
}
