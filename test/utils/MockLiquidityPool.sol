// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {IERC20} from "./interfaces/IWeth.sol";

/**
 * @notice Simplified mock version of Liquidity Pool
 * @dev not to be used for anything other than local tests
 */
contract MockLiquidityPool {
    IERC20 public dai;
    IERC20 public usdt;
    uint256 public daiReserve;
    uint256 public usdtReserve;
    uint256 public price; // Price of 1 DAI in terms of USDT (e.g., price = 1 means 1 DAI = 1 USDT)

    constructor(IERC20 _dai, IERC20 _usdt, uint256 initialDai, uint256 initialUsdt) {
        dai = _dai;
        usdt = _usdt;
        daiReserve = initialDai;
        usdtReserve = initialUsdt;
        price = 1e18; // 1 DAI = 1 USDT initially
    }

    function addLiquidity(uint256 amountDai, uint256 amountUsdt) external {
        dai.transferFrom(msg.sender, address(this), amountDai);
        usdt.transferFrom(msg.sender, address(this), amountUsdt);
        daiReserve += amountDai;
        usdtReserve += amountUsdt;
    }

    function removeLiquidity(uint256 amountDai, uint256 amountUsdt) external {
        require(daiReserve >= amountDai, "Not enough DAI in pool");
        require(usdtReserve >= amountUsdt, "Not enough USDT in pool");

        dai.transfer(msg.sender, amountDai);
        usdt.transfer(msg.sender, amountUsdt);

        daiReserve -= amountDai;
        usdtReserve -= amountUsdt;
    }

    function swap(address tokenIn, uint256 amountIn) external {
        require(tokenIn == address(dai) || tokenIn == address(usdt), "Unsupported token");

        if (tokenIn == address(dai)) {
            uint256 amountOut = (amountIn * price) / 1e18;
            require(usdtReserve >= amountOut, "Not enough USDT liquidity");
            dai.transferFrom(msg.sender, address(this), amountIn);
            usdt.transfer(msg.sender, amountOut);
            daiReserve += amountIn;
            usdtReserve -= amountOut;
        } else {
            uint256 amountOut = (amountIn * 1e18) / price;
            require(daiReserve >= amountOut, "Not enough DAI liquidity");
            usdt.transferFrom(msg.sender, address(this), amountIn);
            dai.transfer(msg.sender, amountOut);
            usdtReserve += amountIn;
            daiReserve -= amountOut;
        }
    }

    function getPrice() external view returns (uint256) {
        return price;
    }

    // TODO : set price according to liquidity avaiable
    function setPrice(uint256 newPrice) external {
        require(newPrice > 0, "Price must be greater than 0");
        price = newPrice;
    }
}
