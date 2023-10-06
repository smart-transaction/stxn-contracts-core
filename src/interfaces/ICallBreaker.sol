// SPDX-License-Identifier: MIT
pragma solidity >=0.6.2 <0.9.0;

import "../TimeTypes.sol";

interface ICallBreaker {
    /// @dev entrypoint to the portal should be in a fallback function
    /// @dev Security Notice: receive function must revert to prevent funds from getting stuck
    function enterPortal(bytes calldata input) external payable returns (bytes memory);

    function verify(bytes memory callObjs, bytes memory returnObjs) external;
}
