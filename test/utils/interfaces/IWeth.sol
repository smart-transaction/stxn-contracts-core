// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.13;

import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";

interface IWETH is IERC20 {
    function deposit() external payable;

    function withdraw(uint256 amount) external;

    function mint(address to, uint256 amount) external;

    function burn(uint256 amount) external;
}

interface IMintableERC20 is IERC20 {
    function mint(address to, uint256 amount) external;

    function burn(uint256 amount) external;
}
