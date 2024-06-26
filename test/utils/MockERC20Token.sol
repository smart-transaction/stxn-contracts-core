// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.13;

import {ERC20} from "openzeppelin/token/ERC20/ERC20.sol";

contract MockERC20Token is ERC20 {
    constructor(string memory tokenName, string memory tokenSymbol) ERC20(tokenName, tokenSymbol) {}

    function mint(uint256 amount, address to) public {
        _mint(to, amount);
    }
}
