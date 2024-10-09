// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

import "src/timetravel/SmarterContract.sol";
import {IMintableERC20} from "test/utils/interfaces/IMintableERC20.sol";

contract MockDaiWethPool is SmarterContract {
    uint256 public constant DECIMAL = 1e18;

    uint256 private _balanceOfWeth;
    uint256 private _balanceOfDai;

    address public owner;
    IMintableERC20 public weth;
    IMintableERC20 public dai;

    event LiquiditySetForPriceTest();

    error InvalidPriceLimit();

    constructor(address _callbreaker, address _dai, address _weth) SmarterContract(_callbreaker) {
        dai = IMintableERC20(_dai);
        weth = IMintableERC20(_weth);
        owner = msg.sender;
    }

    function mintInitialLiquidity() external {
        dai.mint(address(this), 100 * DECIMAL);
        weth.mint(address(this), 10 * DECIMAL);
        _balanceOfWeth = 10 * DECIMAL;
        _balanceOfDai = 100 * DECIMAL;
    }

    function swapDAIForWETH(uint256 _amountIn, uint256 slippagePercent) public returns (uint256 amountOut) {
        uint256 amountIn = _amountIn * 1e18;
        require(dai.transferFrom(msg.sender, address(this), amountIn), "transferFrom failed.");

        _balanceOfDai += amountIn;
        amountOut = (amountIn * _balanceOfWeth) / _balanceOfDai;
        _balanceOfWeth -= amountOut;
        require(weth.transfer(msg.sender, amountOut), "transferFrom failed.");

        // check whether or not
        CallObject[] memory callObjs = new CallObject[](1);
        callObjs[0] = CallObject({
            amount: 0,
            addr: address(this),
            gas: 10000000,
            callvalue: abi.encodeWithSignature("checkSlippage(uint256)", slippagePercent)
        });

        assertFutureCallTo(callObjs[0]);
    }

    function provideLiquidityToDAIETHPool(address provider, uint256 _amount0In, uint256 _amount1In) external {
        uint256 amount0Desired = _amount0In * 1e18;
        uint256 amount1Desired = _amount1In * 1e18;
        require(dai.transferFrom(provider, address(this), amount0Desired), "transferFrom _amount0In failed.");
        require(weth.transferFrom(provider, address(this), amount1Desired), "transferFrom _amount1In failed.");

        _balanceOfDai += amount0Desired;
        _balanceOfWeth += amount1Desired;
    }

    function withdrawLiquidityFromDAIETHPool(address provider, uint256 _amount0Out, uint256 _amount1Out) external {
        uint256 amount0Desired = _amount0Out * 1e18;
        uint256 amount1Desired = _amount1Out * 1e18;
        require(dai.transfer(provider, amount0Desired), "transferFrom _amount0Out failed.");
        require(weth.transfer(provider, amount1Desired), "transferFrom _amount1Out failed.");

        _balanceOfDai -= amount0Desired;
        _balanceOfWeth -= amount1Desired;
    }

    /// @notice functions to allow setting prices for price based test scenarios
    function setExactLiquidity(uint256 amount0, uint256 amount1) external {
        uint256 amount0Desired = amount0 * 1e18;
        uint256 amount1Desired = amount1 * 1e18;

        if (amount0Desired > _balanceOfDai) {
            // mint Dai if new liquidity amount is higher
            uint256 mintAmountDai = amount0Desired - _balanceOfDai;
            dai.mint(address(this), mintAmountDai);
        } else if (amount0Desired < _balanceOfDai) {
            // burn Dai if new liquidity amount is lower
            uint256 burnAmountDai = _balanceOfDai - amount0Desired;
            dai.burn(address(this), burnAmountDai);
        }

        if (amount1Desired > _balanceOfWeth) {
            // mint Weth if new liquidity amount is higher
            uint256 mintAmountWeth = amount1Desired - _balanceOfWeth;
            weth.mint(address(this), mintAmountWeth);
        } else if (amount1Desired < _balanceOfWeth) {
            // burn Weth if new liquidity amount is lower
            uint256 burnAmountWeth = _balanceOfWeth - amount1Desired;
            weth.burn(address(this), burnAmountWeth);
        }

        emit LiquiditySetForPriceTest();
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

    function getPriceOfDai() external view returns (uint256) {
        return (_balanceOfDai / _balanceOfWeth);
    }
}
