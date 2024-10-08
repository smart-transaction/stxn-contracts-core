// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {IERC20} from "test/utils/interfaces/IMintableERC20.sol";

/**
 * @notice Simplified mock version of Flash Loan Provider
 * @dev not to be used for anything other than tests and demo
 */
contract MockLiquidityProvider {
    uint256 public constant DECIMAL = 1e18;

    IERC20 public tokenA;
    IERC20 public tokenB;

    constructor(IERC20 _tokenA, IERC20 _tokenB) {
        tokenA = _tokenA;
        tokenB = _tokenB;
    }

    function approveTransfer(address caller, uint256 amountA, uint256 amountB) external returns (bool) {
        tokenA.approve(msg.sender, amountA);
        tokenB.approve(msg.sender, amountB);
        return true;
    }
}
