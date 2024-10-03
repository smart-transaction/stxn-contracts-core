// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

interface IFlashLoan {
    function flashLoan(address receiver, address tokenA, uint256 amountA, address tokenB, uint256 amountB, bytes data)
        external
        returns (bool);
}
