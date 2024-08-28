// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

import "openzeppelin-upgradeable/access/AccessControlUpgradeable.sol";

/// @custom:oz-upgrades-from Faucet
contract FaucetV1 is AccessControlUpgradeable {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    uint256 public dripAmount;
    uint256 public lockDuration;

    /// @notice used to block users of faucet for 24 hours after taking every call
    /// @dev mapping to store address and blocktime + 1 day
    mapping(address => uint256) public lockTime;

    event DripAmountUpdated(uint256 amount);
    event LockDurationUpdated(uint256 lockDuration);
    event FundsTransferred(address indexed requestor, uint256 dripAmount);
    event FundsGranted(address indexed receiver, uint256 amount);

    function initialize() external initializer {
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _grantRole(ADMIN_ROLE, _msgSender());
        _setDripAmount(0.5 ether);
        lockDuration = 1 days;
    }

    /// @notice call to get funds from the faucet
    function requestFunds(address payable _requestor) external payable {
        // check if funds were transferred recently
        require(block.timestamp > lockTime[_requestor], "Faucet: Please try later");
        // check if there is enough balance
        require(address(this).balance > dripAmount, "Faucet: Not enough funds");

        _requestor.transfer(dripAmount);
        lockTime[_requestor] = block.timestamp + lockDuration;
        emit FundsTransferred(_requestor, dripAmount);
    }

    /// @notice admin call to grant large funds to a receiver
    function grantFunds(address payable _receiver, uint256 _amount) external payable onlyRole(ADMIN_ROLE) {
        // check if there is enough balance
        require(address(this).balance > _amount, "Faucet: Not enough funds");

        _receiver.transfer(_amount);
        emit FundsGranted(_receiver, _amount);
    }

    /// @notice call to change the amount transferred when requests are made
    function changeDripAmount(uint256 newDripAmount) external onlyRole(ADMIN_ROLE) {
        _setDripAmount(newDripAmount);
    }

    /// @notice
    function changeLockDuration(uint256 newLockDuration) external onlyRole(ADMIN_ROLE) {
        require(newLockDuration > 0, "Faucet: Invalid duration value");
        lockDuration = newLockDuration;
        emit LockDurationUpdated(newLockDuration);
    }

    // function to add funds to the smart contract
    receive() external payable {}

    function _setDripAmount(uint256 newDripAmount) private {
        dripAmount = newDripAmount;
        emit DripAmountUpdated(newDripAmount);
    }
}
