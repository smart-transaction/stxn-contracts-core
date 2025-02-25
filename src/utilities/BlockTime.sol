// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

import "openzeppelin-contracts/contracts/access/AccessControl.sol";
import "openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import "src/tokens/TimeToken.sol";
import "src/interfaces/IBlockTime.sol";

contract BlockTime is IBlockTime, AccessControl, ReentrancyGuard {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant SCHEDULER_ROLE = keccak256("SCHEDULER_ROLE");

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

    /// @notice The ERC20 timeToken that will be transferred to users on successfull time updation
    TimeToken public timeToken;

    event Tick(uint256 currentEarthTimeBlockStart, uint256 currentEarthTimeBlockEnd);
    event BlockTimeUpdated(
        uint256 newEarthTime, Chronicle[] chronicles, address[] timeTokenReceivers, uint256[] amounts
    );
    event MaxBlockWidthSet(uint256 maxBlockWidth);

    constructor(address _admin) {
        timeToken = new TimeToken();
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(ADMIN_ROLE, _admin);
    }

    /// @notice changes earth avg time
    function moveTime(
        Chronicle[] calldata chronicles,
        uint256 meanCurrentEarthTime,
        address[] calldata receivers,
        uint256[] calldata amounts
    ) external onlyRole(SCHEDULER_ROLE) nonReentrant {
        currentEarthTimeAvg = meanCurrentEarthTime;
        timeToken.batchMint(receivers, amounts);
        emit BlockTimeUpdated(meanCurrentEarthTime, chronicles, receivers, amounts);
    }

    /// @notice returns current block time
    /// @return block start epoch
    /// @return block end epoch
    function getBlockTime() external view returns (uint256, uint256) {
        return (currentEarthTimeAvg, currentEarthTimeAvg + maxBlockWidth);
    }

    function setMaxBlockWidth(uint256 _maxBlockWidth) public onlyRole(ADMIN_ROLE) {
        maxBlockWidth = _maxBlockWidth;
        emit MaxBlockWidthSet(_maxBlockWidth);
    }

    function getMaxBlockWidth() public view returns (uint256) {
        return maxBlockWidth;
    }
}
