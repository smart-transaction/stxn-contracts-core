// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

import "openzeppelin/token/ERC20/ERC20.sol";
import "openzeppelin/access/Ownable2Step.sol";

contract TimeToken is ERC20, Ownable2Step {
    // Error if User's and minting amount array's length are not same
    error ArrayLengthMismatch();

    // Event to log batch minting
    event BatchMinted(address[] to, uint256[] amounts);

    constructor(string memory _name, string memory _symbol) ERC20(_name, _symbol) Ownable(_msgSender()) {}

    // Batch mint function
    function batchMint(address[] memory to, uint256[] memory amounts) public onlyOwner {
        if (to.length != amounts.length) {
            revert ArrayLengthMismatch();
        }

        for (uint256 i = 0; i < to.length; ++i) {
            _mint(to[i], amounts[i]);
        }

        emit BatchMinted(to, amounts);
    }
}