// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

import "openzeppelin-contracts/contracts/access/AccessControl.sol";

contract Blockclock is AccessControl {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant TIME_KEEPER = keccak256("TIME_KEEPER");

    struct Chronicle {
        uint256 epoch;
        address timeKeeper;
        bytes32 signature;
    }

    /// @dev minimum number of signed time values needed
    uint256 public minNumberOfChronicles;

    /// @notice value used to ensure the values being provided are not outliers
    uint256 public maxBlockWidth;

    /// @notice since the precision of time is low in this implementation we assume time to be anywhere
    ///         between current mean time and current mean time + time width
    ///         This can be in the future be modified to be an average of the difference between last X earthTimeValues
    uint256 public timeBlockWidth;

    /// @notice the current average of all time keepers provided time value
    uint256 public currentEarthTimeAvg;

    event Tick(uint256 currentEarthTimeBlockStart, uint256 currentEarthTimeBlockEnd);

    error InsufficientEvidence();

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _grantRole(ADMIN_ROLE, _msgSender());
    }

    /// @notice changes earth avg tim
    function moveClock(Chronicle[] calldata chronicles) external {
        // number of chronicles submitted should be greater than a threshold value
        uint256 len = chronicles.length;
        if (len < minNumberOfChronicles) {
            revert InsufficientEvidence();
        }

        // all time keepers should be whitelisted i.e. have the Time Keeper role
        // all the time values should be greater than currentEarthTimeAvg and less than currentEarthTimeAvg + maxBlockWidth
        // emit Tick(uint256, /*currentEarthTimeBlockStart*/ uint256 /*currentEarthTimeBlockEnd*/ );
    }

    /// @notice returns current block time
    /// @return block start epoch
    /// @return block end epoch
    function getBlockTime() external view returns (uint256, uint256) {
        return (currentEarthTimeAvg, currentEarthTimeAvg + maxBlockWidth);
    }
}
