// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

import {IWETH, IMintableERC20} from "test/utils/interfaces/IWeth.sol";
import {ISwapRouter} from "test/utils/interfaces/ISwapRouter.sol";

/**
 * @notice Oversimplified mock version of a router
 * @dev not to be used for anything other than local tests
 */
contract SwapPool is ISwapRouter {
    uint256 public constant DECIMAL = 1e18;

    uint256 private _balanceOfWeth;
    uint256 private _balanceOfDai;

    IWETH private _weth;
    IMintableERC20 private _dai;

    event LiquiditySetForPriceTest();

    error InvalidPriceLimit();

    constructor(address dai, address weth) {
        _dai = IMintableERC20(dai);
        _weth = IWETH(weth);

        // let initial liquidity be 10 Weth for 100 Dai for the purpose of this mock
        _balanceOfDai = 100 * DECIMAL;
        _balanceOfWeth = 10 * DECIMAL;
        _dai.mint(address(this), _balanceOfDai);
        _weth.mint(address(this), _balanceOfWeth);
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

    /// @notice functions to allow setting prices for price based test scenarios
    function setExactLiquidity(uint256 amount0, uint256 amount1) external {
        // Ensure amounts are greater than a minimum threshold (DECIMAL)
        require(amount0 > DECIMAL, "LiquidityTooLow");
        require(amount1 > DECIMAL, "LiquidityTooLow");

        if (amount0 > _balanceOfDai) {
            // mint Dai if new liquidity amount is higher
            uint256 mintAmountDai = amount0 - _balanceOfDai;
            _dai.mint(address(this), mintAmountDai);
        } else if (amount0 < _balanceOfDai) {
            // burn Dai if new liquidity amount is lower
            uint256 burnAmountDai = _balanceOfDai - amount0;
            _dai.burn(burnAmountDai);
        }

        if (amount1 > _balanceOfWeth) {
            // mint Weth if new liquidity amount is higher
            uint256 mintAmountWeth = amount1 - _balanceOfWeth;
            _weth.mint(address(this), mintAmountWeth);
        } else if (amount1 < _balanceOfWeth) {
            // burn Weth if new liquidity amount is lower
            uint256 burnAmountWeth = _balanceOfWeth - amount1;
            _weth.burn(burnAmountWeth);
        }

        emit LiquiditySetForPriceTest();
    }

    function getPriceOfDai() external view returns (uint256) {
        return (_balanceOfDai / _balanceOfWeth);
    }
}
