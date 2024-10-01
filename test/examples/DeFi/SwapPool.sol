// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

import "src/timetravel/CallBreaker.sol";
import "src/timetravel/SmarterContract.sol";
import "src/TimeTypes.sol";
import "test/utils/interfaces/ISwapRouter.sol";

import {IWETH, IERC20} from "test/utils/interfaces/IWeth.sol";

contract SwapPool is SmarterContract {
    uint256 public constant DECIMAL = 1e18;

    ISwapRouter private immutable router;

    address owner;
    address callbreakerAddress;

    IWETH private weth;
    IERC20 private dai;



    constructor(address _router, address _callbreakerAddress, address _positionManager, address _dai, address _weth)
        SmarterContract(_callbreakerAddress)
    {
        router = ISwapRouter(_router);
        callbreakerAddress = _callbreakerAddress;
        dai = IERC20(_dai);
        weth = IWETH(_weth);
    }

    error InvalidPriceLimit();

    // use the timeturner to enforce slippage on a uniswap trade
    // set slippage really high, let yourself slip, then use the timeturner to revert the trade if the price was above some number.
    function swapDAIForWETH(uint256 _amountIn, uint256 slippagePercent) public {
        uint256 amountIn = _amountIn * 1e18;
        require(dai.transferFrom(msg.sender, address(router), amountIn), "transferFrom failed.");
        require(dai.approve(address(router), amountIn), "approve failed.");


        // // perform the swap with no slippage limits
        // ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
        //     tokenIn: address(dai),
        //     tokenOut: address(weth),
        //     fee: poolFee,
        //     recipient: msg.sender,
        //     deadline: block.timestamp,
        //     amountIn: amountIn,
        //     amountOutMinimum: 0,
        //     sqrtPriceLimitX96: 0
        // });

        // The call to `exactInputSingle` executes the swap.
        // TODO: trasnsfer amount1 to reciever
        router.exactInputSingle(params.amount0Desired, params.amount1Desired);

        // check whether or not
        CallObject[] memory callObjs = new CallObject[](1);
        callObjs[0] = CallObject({
            amount: 0,
            addr: address(router),
            gas: 10000000,
            callvalue: abi.encodeWithSignature("checkSlippage(uint256)", slippagePercent)
        });

        assertFutureCallTo(callObjs[0]);
    }

    function provideLiquidityToDAIETHPool(uint256 _amount0In, uint256 _amount1In) external {
        uint256 amount0Desired = _amount0In * 1e18;
        uint256 amount1Desired = _amount1In * 1e18;
        // uint256 amount0Min = _amount0In * 1e18 * 90 / 100;
        // uint256 amount1Min = _amount1In * 1e18 * 90 / 100;

           /// TODO: transfer liquidity tokens to pool
        // IPositionManager.MintParams memory params = IPositionManager.MintParams({
        //     token0: address(dai),
        //     token1: address(weth),
        //     fee: poolFee,
        //     tickLower: 0,
        //     tickUpper: 10000,
        //     amount0Desired: amount0Desired,
        //     amount1Desired: amount1Desired,
        //     amount0Min: amount0Min,
        //     amount1Min: amount1Min,
        //     recipient: msg.sender,
        //     deadline: block.timestamp
        // });

        // (tokenId, liquidityProvided, amount0Deposited, amount1Deposited) =
        //     IPositionManager(positionManager).mint(params);
        
        router.addLiquidity(amount0Desired, amount1Desired);
    }

    function withdrawLiquidityFromDAIETHPool(uint256 _amount0Out, uint256 _amount1Out) external {
        uint256 amount0Desired = _amount0Out * 1e18;
        uint256 amount1Desired = _amount1Out * 1e18;

        // uint256 amount0 = amount0Deposited - (amount0Deposited / 100);
        // uint256 amount1 = amount1Deposited - (amount1Deposited / 100);

        // IPositionManager.DecreaseLiquidityParams memory params = IPositionManager.DecreaseLiquidityParams({
        //     tokenId: tokenId,
        //     liquidity: liquidityProvided,
        //     amount0Min: amount0Min,
        //     amount1Min: amount1Min,
        //     deadline: block.timestamp
        // });

        // IPositionManager(positionManager).decreaseLiquidity(params);

        router.removeLiquidity(amount0Desired, amount1Desired);
        /// TODO: transfer tokens to provider of liquidity
    }

    function checkSlippage(uint256 maxDeviationPercentage) external view {
        router.checkSlippage(maxDeviationPercentage);
    }
}
