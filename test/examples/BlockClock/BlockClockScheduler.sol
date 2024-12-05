// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

import "src/utilities/Blockclock.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";

interface IDisbursalContract {
    function spendCoins(address[] calldata _receivers, uint256[] calldata _amounts) external;
}

/**
 * @notice This is an POC example of a block scheduler
 */
contract BlockClockScheduler is Ownable {
    constructor() Ownable(_msgSender()) {}
}