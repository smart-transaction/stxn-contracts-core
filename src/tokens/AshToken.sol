// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-contracts/contracts/access/AccessControl.sol";

// ASH Token Contract
contract AshToken is ERC20, AccessControl {
    // Define the MINTER_ROLE constant
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    // Public variable to track the latest block number when tokens are minted
    uint256 public latestMintBlock;

    // Event to notify when the latestMintBlock is updated
    event LatestMintBlockUpdated(uint256 blockNumber);

    // Error to be thrown when zero address is provided while minting tokens
    error InvalidMintAddress();

    constructor(address admin) ERC20("ASH Token", "ASH") {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(MINTER_ROLE, admin);
    }

    function mint(address to, uint256 amount, uint256 latestBlockNumber) external onlyRole(MINTER_ROLE) {
        require(to != address(0), InvalidMintAddress());
        require(latestBlockNumber - latestMintBlock == 1, "Inconsistent Update");
        latestMintBlock++;
        emit LatestMintBlockUpdated(latestBlockNumber);

        _mint(to, amount);
    }
}
