// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

import "src/timetravel/CallBreaker.sol";
import "src/timetravel/SmarterContract.sol";
import "src/TimeTypes.sol";
import "test/utils/interfaces/ISwapPool.sol";

import {IWETH, IERC20} from "test/utils/interfaces/IWeth.sol";

contract MockSwapRouter is SmarterContract {
    uint256 public constant DECIMAL = 1e18;

    ISwapPool private immutable pool;

    address owner;
    address callbreakerAddress;

    IWETH private weth;
    IERC20 private dai;

    constructor(address _pool, address _callbreakerAddress, address _dai, address _weth)
        SmarterContract(_callbreakerAddress)
    {
        pool = ISwapPool(_pool);
        callbreakerAddress = _callbreakerAddress;
        dai = IERC20(_dai);
        weth = IWETH(_weth);
    }

    error InvalidPriceLimit();

    function swapDAIForWETH(uint256 _amountIn, uint256 slippagePercent) public {
        uint256 amountIn = _amountIn * 1e18;
        require(dai.transferFrom(msg.sender, address(pool), amountIn), "transferFrom failed.");

        ISwapPool.ExactInputSingleParams memory params = ISwapPool.ExactInputSingleParams({
            tokenIn: address(dai),
            tokenOut: address(weth),
            recipient: msg.sender,
            deadline: block.timestamp,
            amountIn: amountIn,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        });

        uint256 amountOut = pool.exactInputSingle(params);
        require(weth.transferFrom(address(pool), msg.sender, amountOut), "transferFrom failed.");

        // check whether or not
        CallObject[] memory callObjs = new CallObject[](1);
        callObjs[0] = CallObject({
            amount: 0,
            addr: address(pool),
            gas: 10000000,
            callvalue: abi.encodeWithSignature("checkSlippage(uint256)", slippagePercent)
        });

        assertFutureCallTo(callObjs[0]);
    }

    function provideLiquidityToDAIETHPool(uint256 _amount0In, uint256 _amount1In) external {
        uint256 amount0Desired = _amount0In * 1e18;
        uint256 amount1Desired = _amount1In * 1e18;
        require(dai.transferFrom(msg.sender, address(pool), amount0Desired), "transferFrom _amount0In failed.");
        require(weth.transferFrom(msg.sender, address(pool), amount1Desired), "transferFrom _amount1In failed.");

        pool.addLiquidity(amount0Desired, amount1Desired);
    }

    function withdrawLiquidityFromDAIETHPool(uint256 _amount0Out, uint256 _amount1Out) external {
        uint256 amount0Desired = _amount0Out * 1e18;
        uint256 amount1Desired = _amount1Out * 1e18;
        require(dai.transferFrom(address(pool), msg.sender, amount0Desired), "transferFrom _amount0Out failed.");
        require(weth.transferFrom(address(pool), msg.sender, amount1Desired), "transferFrom _amount1Out failed.");

        pool.removeLiquidity(amount0Desired, amount1Desired);
    }

    function checkSlippage(uint256 maxDeviationPercentage) external view {
        pool.checkSlippage(maxDeviationPercentage);
    }
}
