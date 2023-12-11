// SPDX-License-Identifier: MIT
pragma solidity >=0.6.2 <0.9.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "v3-periphery/interfaces/ISwapRouter.sol";
import "v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "v3-core/contracts/libraries/TickMath.sol";

import "openzeppelin/token/ERC20/ERC20.sol";
import "../../src/timetravel/CallBreaker.sol";
import "../../src/timetravel/SmarterContract.sol";
import "../../src/TimeTypes.sol";

address constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
address constant WETH9 = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
address constant SwapRouter = 0xE592427A0AEce92De3Edee1F18E0157C05861564;

// pool fee, 0.3%.
uint24 constant poolFee = 3000;

interface IWETH is IERC20 {
    function deposit() external payable;

    function withdraw(uint256 amount) external;
}

// This example uses fork test:
// FORK_URL=https://eth-mainnet.g.alchemy.com/v2/613t3mfjTevdrCwDl28CVvuk6wSIxRPi
// forge test -vv --gas-report --fork-url $FORK_URL --match-path test/LimitOrder.t.sol
contract LimitOrder is SmarterContract {
    address owner;
    address callbreakerAddress;

    IWETH private weth = IWETH(WETH9);
    IERC20 private dai = IERC20(DAI);
    ISwapRouter constant router = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    uint256 currentMarketPrice;

    event DebugAddress(string message, address value);
    event DebugInfo(string message, string value);
    event DebugUint(string message, uint256 value);

    constructor(address _callbreakerAddress) SmarterContract(_callbreakerAddress) {
        callbreakerAddress = _callbreakerAddress;
    }

    error InvalidPriceLimit();

    // use the timeturner to enforce slippage on a uniswap trade
    // set slippage really high, let yourself slip, then use the timeturner to revert the trade if the price was above some number.
    function swapDAIForWETH(uint256 _amountIn, uint256 slippagePercent) public {
        uint256 amountIn = _amountIn * 1e18;
        require(dai.transferFrom(msg.sender, address(this), amountIn), "transferFrom failed.");
        require(dai.approve(address(router), amountIn), "approve failed.");

        // perform the swap with no slippage limits
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: address(dai),
            tokenOut: address(weth),
            fee: poolFee,
            recipient: msg.sender,
            deadline: block.timestamp,
            amountIn: amountIn,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        });

        // The call to `exactInputSingle` executes the swap.
        uint256 amountOut = router.exactInputSingle(params);
        console.log("WETH", amountOut);

        // check whether or not
        CallObject memory callObj = CallObject({
            amount: 0,
            addr: address(this),
            gas: 1000000,
            callvalue: abi.encodeWithSignature("checkSlippage(uint256)", slippagePercent)
        });

        assertFutureCallTo(callObj, 1);
    }

    function checkSlippage(uint160 targetSlippage) public view {
        IUniswapV3Pool pool = IUniswapV3Pool(address(0xC2e9F25Be6257c210d7Adf0D4Cd6E3E881ba25f8));

        (uint160 sqrtPriceX96,,,,,,) = pool.slot0();

        int24 tickLower = sqrtPriceX96 > TickMath.MIN_SQRT_RATIO
            ? TickMath.getTickAtSqrtRatio(sqrtPriceX96 - (sqrtPriceX96 / targetSlippage))
            : TickMath.MIN_TICK;
        int24 tickUpper = sqrtPriceX96 < TickMath.MAX_SQRT_RATIO
            ? TickMath.getTickAtSqrtRatio(sqrtPriceX96 + (sqrtPriceX96 / targetSlippage))
            : TickMath.MAX_TICK;

        uint160 sqrtPriceLowerX96 = TickMath.getSqrtRatioAtTick(tickLower);
        uint160 sqrtPriceUpperX96 = TickMath.getSqrtRatioAtTick(tickUpper);

        if (sqrtPriceX96 > sqrtPriceLowerX96 || sqrtPriceX96 < sqrtPriceUpperX96) revert InvalidPriceLimit();
    }
}
