// SPDX-License-Identifier: MIT
pragma solidity >=0.6.2 <0.9.0;

import "../TimeTypes.sol";

interface ICallBreaker {
    /// @notice Verifies the call stack by checking the provided return values against the actual return values of the callObjects
    /// @dev This function will revert if the call stack fails to verify.
    /// @param callObjs The call objects that were executed.
    /// @param returnObjs The return objects that were returned from the call objects.
    function verify(bytes memory callObjs, bytes memory returnObjs) external;
}
