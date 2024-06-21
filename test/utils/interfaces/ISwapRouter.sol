// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.13;

interface ISwapRouter {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint256 amountOut);

    function addLiquidity(uint256 amount0, uint256 amount1) external;

    function removeLiquidity(uint256 amount0, uint256 amount1) external;
}