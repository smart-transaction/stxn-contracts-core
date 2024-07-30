// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

import {IWETH, IERC20} from "../utils/interfaces/IWeth.sol";
import {ISwapRouter} from "../utils/interfaces/ISwapRouter.sol";

/**
 * @notice Oversimplified mock version of a router
 * @dev not to be used for anything other than local tests
 */
contract MockSwapRouter is ISwapRouter {
    uint256 public constant DECIMAL = 1e18;

    uint256 private _balanceOfWeth;
    uint256 private _balanceOfDai;

    IWETH private _weth;
    IERC20 private _dai;

    error InvalidPriceLimit();

    constructor(address dai, address weth) {
        _dai = IERC20(dai);
        _weth = IWETH(weth);

        // let initial liquidity be 10 Weth for 100 Dai
        _balanceOfDai = 100 * DECIMAL;
        _balanceOfWeth = 10 * DECIMAL;
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

    function checkSlippage(uint256 maxDeviationPercentage) external view {
        // Calculate the current price (ratio) of DAI to WETH
        uint256 currentPrice = (_balanceOfDai * DECIMAL) / _balanceOfWeth;

        // Assume initial expected price of 10 due to initial DAI and WETH ratio
        uint256 expectedPrice = 10 * DECIMAL;

        // Calculate the absolute deviation in percentage
        uint256 slippage = (
            currentPrice > expectedPrice ? (currentPrice - expectedPrice) : (expectedPrice - currentPrice)
        ) / expectedPrice;

        if (slippage > maxDeviationPercentage) revert InvalidPriceLimit();
    }
}
