// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {IERC20} from "./interfaces/IMintableERC20.sol";

interface IFlashLoanBorrower {
    function onFlashLoan(address initiator, address token1, uint256 amount1, address token2, uint256 amount2)
        external
        returns (bytes32);
}

/**
 * @notice Simplified mock version of Flash Loan Provider
 * @dev not to be used for anything other than tests and demo
 */
contract MockFlashLoan {
    uint256 public constant DECIMAL = 1e18;

    IERC20 public weth;
    IERC20 public dai;

    constructor(IERC20 _weth, IERC20 _dai) {
        weth = _weth;
        dai = _dai;
    }

    function maxFlashLoan() external view returns (uint256, uint256) {
        return (weth.balanceOf(address(this)), dai.balanceOf(address(this)));
    }

    function flashLoan(
        address receiver,
        uint256 usdtAmount,
        bytes calldata usdtData,
        uint256 daiAmount,
        bytes calldata daiData
    ) external returns (bool) {
        uint256 usdtFee = flashFee(address(usdt), _balanceOfUsdt);
        uint256 daiFee = flashFee(address(dai), _balanceOfDai);

        require(usdtAmount <= _balanceOfUsdt, "Insufficient usdt liquidity");
        require(daiAmount <= _balanceOfDai, "Insufficient dai liquidity");

        // Transfer tokens to the borrower
        weth.transfer(receiver, amountA);
        dai.transfer(receiver, amountB);

        // Call the borrower's onFlashLoan function once (consolidated)
        IFlashLoanBorrower(receiver).onFlashLoan(msg.sender, address(usdt), usdtAmount, address(dai), daiAmount);

        // Fetch the amount + fee via transferFrom
        weth.transferFrom(receiver, address(this), amountA);
        dai.transferFrom(receiver, address(this), amountB);

        return true;
    }
}
