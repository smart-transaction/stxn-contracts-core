// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {IERC20} from "./interfaces/IWeth.sol";

interface IFlashLoanBorrower {
    function onFlashLoan(address initiator, address token1, uint256 amount1, address token2, uint256 amount2)
        external
        returns (bytes32);
}

/**
 * @notice Simplified mock version of Flash Loan Provider
 * @dev not to be used for anything other than local tests
 */
contract MockFlashLoan {
    uint256 public constant DECIMAL = 1e18;

    uint256 private _balanceOfUsdt;
    uint256 private _balanceOfDai;

    IERC20 public usdt;
    IERC20 public dai;

    uint256 public feePercentage = 10; // 1%

    constructor(IERC20 _usdt, IERC20 _dai) {
        usdt = _usdt;
        dai = _dai;

        // let initial liquidity be 100 for both Usdt & Dai
        _balanceOfDai = 100 * DECIMAL;
        _balanceOfUsdt = 100 * DECIMAL;
    }

    function maxFlashLoan() external view returns (uint256 usdtBalance, uint256 daiBalance) {
        return (_balanceOfUsdt, _balanceOfDai);
    }

    function flashFee(address tokenAddress, uint256 amount) public view returns (uint256) {
        require(tokenAddress == address(usdt) || tokenAddress == address(dai), "Unsupported token");
        return (amount * feePercentage) / 1000; // Fee as 1% of the loaned amount
    }

    function flashLoan(
        address receiver,
        uint256 usdtAmount,
        uint256 daiAmount
    ) external returns (bool) {
        uint256 usdtFee = flashFee(address(usdt), _balanceOfUsdt);
        uint256 daiFee = flashFee(address(dai), _balanceOfDai);

        require(usdtAmount <= _balanceOfUsdt, "Insufficient usdt liquidity");
        require(daiAmount <= _balanceOfDai, "Insufficient dai liquidity");

        // Transfer tokens to the borrower
        usdt.transfer(receiver, usdtAmount);
        dai.transfer(receiver, daiAmount);

        // Call the borrower's onFlashLoan function once (consolidated)
        IFlashLoanBorrower(receiver).onFlashLoan(msg.sender, address(usdt), usdtAmount, address(dai), daiAmount);

        // Fetch the amount + fee via transferFrom
        usdt.transferFrom(receiver, address(this), usdtAmount + usdtFee);
        dai.transferFrom(receiver, address(this), daiAmount + daiFee);

        return true;
    }
}
