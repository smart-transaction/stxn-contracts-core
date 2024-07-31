// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.13;

import {IPositionManager} from "./interfaces/IPositionManager.sol";
import {ISwapRouter} from "./interfaces/ISwapRouter.sol";

/**
 * @notice Oversimplified mock version of a Position Manager
 * @dev not to be used for anything other than local tests
 */
contract MockPositionManager is IPositionManager {
    uint256 public positionId;

    ISwapRouter private mockSwapRouter;

    constructor(address _mockSwapRouter) {
        mockSwapRouter = ISwapRouter(_mockSwapRouter);
    }

    function mint(MintParams calldata params)
        external
        payable
        returns (uint256 tokenId, uint128 liquidity, uint256 amount0, uint256 amount1)
    {
        mockSwapRouter.addLiquidity(params.amount0Desired, params.amount1Desired);
        tokenId = 1;
        liquidity = 1;
        amount0 = params.amount0Desired;
        amount1 = params.amount1Desired;
    }

    function decreaseLiquidity(DecreaseLiquidityParams calldata params)
        external
        payable
        returns (uint256 amount0, uint256 amount1)
    {
        mockSwapRouter.removeLiquidity(params.amount0Min, params.amount1Min);
        amount0 = params.amount0Min;
        amount1 = params.amount1Min;
    }
}
