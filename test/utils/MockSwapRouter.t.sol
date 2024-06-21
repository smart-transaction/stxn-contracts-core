// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.13;

import {IWETH, IERC20} from "../utils/interfaces/IWeth.sol";
import {ISwapRouter} from "../utils/interfaces/ISwapRouter.sol";

/**
 * @notice Oversimplified mock version of a router
 * @dev not to be used for anything other than local tests
*/ 
contract MockSwapRouter is ISwapRouter {
    uint256 public constant DECIMAL = 18;

    uint256 private _balanceOfWeth;
    uint256 private _balanceOfDai;

    IWETH private _weth;
    IERC20 private _dai;

    constructor(address weth, address dai) {
        _weth = IWETH(weth);
        _dai = IERC20(dai);

        // let initial liquidity be 10 Weth for 100 Dai
        _balanceOfWeth = 10 * DECIMAL;
        _balanceOfDai = 100 * DECIMAL;
    }

    function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint256 amountOut) {
        _balanceOfDai += params.amountIn;
        amountOut = (params.amountIn * _balanceOfWeth) / _balanceOfDai;
        _balanceOfWeth -= amountOut;
    }

    function addLiquidity(uint256 amount0, uint256 amount1) external {
        _balanceOfDai += amount0;
        _balanceOfWeth += amount1;
    }

    function removeLiquidity(uint256 amount0, uint256 amount1) external {
        _balanceOfDai -= amount0;
        _balanceOfWeth -= amount1;
    }
}
