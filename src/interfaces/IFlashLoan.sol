// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

import "../TimeTypes.sol";
interface IFlashLoan {
    function flashLoan(address receiver, uint256 amountA, uint256 amountB, CallObject[] calldata callObjs)
        external
        returns (bool);
}
