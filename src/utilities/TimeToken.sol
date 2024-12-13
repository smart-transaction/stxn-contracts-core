// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

import "openzeppelin/token/ERC20/ERC20.sol";
import "openzeppelin/access/Ownable.sol";

contract TimeToken is ERC20, Ownable {
    // Error if User's and minting amount array's length are not same
    error ArrayLengthMismatch();

    // Event to log batch minting
    event BatchMinted(address[] to, uint256[] amounts);

    constructor() ERC20("TimeToken", "TIME") Ownable(msg.sender) {}

    // Batch mint function
    /// @dev The onlyOwner modifier will be later changed to execute calls through a governance proposal
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