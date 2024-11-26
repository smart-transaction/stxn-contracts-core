// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {IERC20} from "test/utils/interfaces/IMintableERC20.sol";
import "src/TimeTypes.sol";

interface IFlashLoanBorrower {
    function onFlashLoan(
        address initiator,
        address token1,
        uint256 amount1,
        address token2,
        uint256 amount2,
        CallObject[] calldata callObjs
    ) external returns (bool);
}

/**
 * @notice Simplified mock version of Flash Loan Provider
 * @dev not to be used for anything other than tests and demo
 */
contract MockFlashLoan {
    uint256 public constant DECIMAL = 1e18;

    IERC20 public weth;
    IERC20 public dai;

    constructor(address _dai, address _weth) {
        dai = IERC20(_dai);
        weth = IERC20(_weth);
    }

    function maxFlashLoan() external view returns (uint256, uint256) {
        return (dai.balanceOf(address(this)), weth.balanceOf(address(this)));
    }

    function flashLoan(address receiver, uint256 daiAmount, uint256 wethAmount, CallObject[] calldata callObjs)
        external
        returns (bool)
    {
        require(dai.transfer(receiver, daiAmount), "Insufficient dai liquidity");
        require(weth.transfer(receiver, wethAmount), "Insufficient usdt liquidity");

        // Call the borrower's onFlashLoan function once (consolidated)
        IFlashLoanBorrower(receiver).onFlashLoan(msg.sender, address(dai), daiAmount, address(weth), wethAmount, callObjs);

        // Fetch the amount + fee via transferFrom
        require(dai.transferFrom(receiver, address(this), daiAmount), "Loan repayment failed");
        require(weth.transferFrom(receiver, address(this), wethAmount), "Loan repayment failed");

        return true;
    }
}
