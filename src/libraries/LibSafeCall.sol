// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library LibSafeCall {
  /**
   * @dev Gas cost to check before executing call opcode in the method `callWithExactGas`.
   * 5000 is plenty for an EXTCODESIZE call (2600) + warm CALL (100) and some arithmetic operations.
   *
   */
  uint256 private constant GAS_FOR_CALL_EXACT_CHECK = 5_000;

  /**
   * @dev Calls to the target address with exact gas limit. Returns the call result status.
   */
  function callWithExactGas(address target, bytes memory data, uint256 gasAmount) internal returns (bool success) {
    assembly {
      let g := gas()
      // Compute g -= GAS_FOR_CALL_EXACT_CHECK and check for underflow
      // The gas actually passed to the callee is min(gasAmount, 63//64*gas available).
      // We want to ensure that we revert if gasAmount >  63//64*gas available
      // as we do not want to provide them with less, however that check itself costs
      // gas.  GAS_FOR_CALL_EXACT_CHECK ensures we have at least enough gas to be able
      // to revert if gasAmount >  63//64*gas available.
      if lt(g, GAS_FOR_CALL_EXACT_CHECK) { revert(0, 0) }
      g := sub(g, GAS_FOR_CALL_EXACT_CHECK)
      // if g - g//64 <= gasAmount, revert
      // (we subtract g//64 because of EIP-150)
      if iszero(gt(sub(g, div(g, 64)), gasAmount)) { revert(0, 0) }
      // solidity calls check that a contract actually exists at the destination, so we do the same
      if iszero(extcodesize(target)) { revert(0, 0) }
      // call and return whether we succeeded. ignore return data
      // call(gas,addr,value,argsOffset,argsLength,retOffset,retLength)
      success := call(gasAmount, target, 0, add(data, 0x20), mload(data), 0, 0)
    }
    return success;
  }
}
