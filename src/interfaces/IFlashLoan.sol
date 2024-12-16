// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

interface IFlashLoan {
    function flashLoan(address receiver, uint256 amountA, uint256 amountB, bytes memory data)
        external
        returns (bool);
}
