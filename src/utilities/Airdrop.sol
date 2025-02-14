// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract Airdrop is Ownable {
    using SafeERC20 for IERC20;

    address public token;
    bytes32 public merkleRoot;

    mapping(uint256 => uint256) private claimed;

    event Claimed(uint256 index, address account, uint256 amount);
    error TokenAlreadyClaimed(uint256 index, address account, uint256 amount);

    constructor(bytes32 _merkleRoot, address _token) Ownable(msg.sender) {
        merkleRoot = _merkleRoot;
        token = _token;
    }

    function claim(
        uint256 index,
        address account,
        uint256 amount,
        bytes32[] calldata merkleProof
    ) external {
        if (isClaimed(index)) {
            revert TokenAlreadyClaimed(index, account, amount);
        }

        bytes32 node = keccak256(abi.encodePacked(index, account, amount));

        _verifyClaim(merkleProof, node);
        _setClaimed(index);

        IERC20(token).safeTransfer(account, amount);

        emit Claimed(index, account, amount);
    }

    function isClaimed(uint256 index) public view returns (bool) {
        uint256 claimedWordIndex = index / 256;
        uint256 claimedBitIndex = index % 256;
        uint256 claimedWord = claimed[claimedWordIndex];
        uint256 mask = (1 << claimedBitIndex);
        return claimedWord & mask == mask;
    }

    function _setClaimed(uint256 index) internal {
        uint256 claimedWordIndex = index / 256;
        uint256 claimedBitIndex = index % 256;
        claimed[claimedWordIndex] =
            claimed[claimedWordIndex] |
            (1 << claimedBitIndex);
    }

    function _verifyClaim(
        bytes32[] calldata merkleProof,
        bytes32 node
    ) public view {
        console.log("here ");
        require(
            MerkleProof.verify(merkleProof, merkleRoot, node),
            "Invalid proof"
        );
    }
}
