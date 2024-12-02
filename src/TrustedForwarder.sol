// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

import {ERC2771Forwarder} from "openzeppelin/metatx/ERC2771Forwarder.sol";
import {Ownable2Step} from "openzeppelin/access/Ownable2Step.sol";
import {ECDSA} from "openzeppelin/utils/cryptography/ECDSA.sol";

contract TrustedForwarder is ERC2771Forwarder, Ownable2Step {
    using ECDSA for bytes32;

    mapping(address => bool) public isBlacklisted;

    event Blacklisted(address indexed account);
    event Whitelisted(address indexed account);
    event ForwardedCall(address indexed sender, bytes data);

    constructor(string memory name) ERC2771Forwarder(name) Ownable2Step() {}

    function blacklist(address account) public onlyOwner {
        isBlacklisted[account] = true;
        emit Blacklisted(account);
    }

    function whitelist(address account) public onlyOwner {
        isBlacklisted[account] = false;
        emit Whitelisted(account);
    }

    function _msgSender() internal view virtual override returns (address sender) {
        sender = super._msgSender();
        require(!isBlacklisted[sender], "Sender is blacklisted");
        return sender;
    }

    function verifySignature(
        bytes32 hash,
        bytes memory signature,
        address expectedSigner
    ) public pure returns (bool) {
        address signer = hash.toEthSignedMessageHash().recover(signature);
        return signer == expectedSigner;
    }

    function forwardCall(
        address target,
        bytes memory data,
        bytes memory signature,
        address signer
    ) public {
        require(verifySignature(keccak256(data), signature, signer), "Invalid signature");

        emit ForwardedCall(signer, data);
        (bool success, ) = target.call(data);
        require(success, "Forwarded call failed");
    }
}
