// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.6.2 <0.9.0;

import "openzeppelin/token/ERC20/ERC20.sol";

contract MyErc20 is ERC20 {
    address private _owner;

    modifier onlyOwner() {
        require(_owner == msg.sender, "Caller is not owner");
        _;
    }

    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {
        _owner = msg.sender;
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) public onlyOwner {
        _burn(from, amount);
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        emit DebugInfo("Transfer initiated", "Transfer details:");
        emit DebugAddress("Sender: ", msg.sender);
        emit DebugAddress("Recipient: ", recipient);
        emit DebugUint("Amount: ", amount);
        return super.transfer(recipient, amount);
    }

    event DebugInfo(string message, string value);
    event DebugAddress(string message, address value);
    event DebugUint(string message, uint256 value);
}
