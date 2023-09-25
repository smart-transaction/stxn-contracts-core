// SPDX-License-Identifier: MIT
pragma solidity >=0.6.2 <0.9.0;

import "../TimeTypes.sol";

interface ICallBreaker {
    function enterPortal(bytes calldata input) external payable returns (bytes memory);

    function verify(bytes memory callObjs, bytes memory returnObjs) external;
}
