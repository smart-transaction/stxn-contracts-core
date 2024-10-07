// // SPDX-License-Identifier: GPL-3.0
// pragma solidity 0.8.26;

// import {ISwapPool} from "test/utils/interfaces/ISwapPool.sol";

// /**
//  * @notice Oversimplified mock version of a router
//  * @dev amount0 is always dai
//  * @dev not to be used for anything other than local tests
//  */
// contract SwapPool is ISwapPool {



//     IMintableERC20 private _weth;
//     IMintableERC20 private _dai;
//     address private _router;

//     event LiquiditySetForPriceTest();

//     error InvalidPriceLimit();

//     constructor(address dai, address weth, address router) {
//         _dai = IMintableERC20(dai);
//         _weth = IMintableERC20(weth);
//         _router= router;
//     }

//     function mintAndApproveInitialSupply() external {
//         // let initial liquidity be 10 Weth for 100 Dai for the purpose of this mock
//         _balanceOfDai = 100 * DECIMAL;
//         _balanceOfWeth = 10 * DECIMAL;
//         _dai.mint(address(this), _balanceOfDai);
//         _weth.mint(address(this), _balanceOfWeth);
//         _dai.approve(_router, 100000000000e18 * DECIMAL);
//         _weth.approve(_router, 100000000000e18 * DECIMAL);
//     }

//     function exactInputSingle(ExactInputSingleParams calldata params) external payable returns ( amountOut) {

//     }

//     function addLiquidity(uint256 amount0, uint256 amount1) external {

//     }

//     function removeLiquidity(uint256 amount0, uint256 amount1) external {

//     }

//     function checkSlippage(uint256 maxDeviationPercentage) external view {

//     }




// }
