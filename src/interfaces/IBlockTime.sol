// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

import "openzeppelin-contracts/contracts/access/IAccessControl.sol";
import "openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

interface IBlockTime {

    struct Chronicle {
        uint256 epoch;
        address timeKeeper;
        bytes signature;
    }

    /// @notice changes earth avg time
    /// @param chronicles List of chronicle data containing epoch, timeKeeper, and signature
    /// @param meanCurrentEarthTime The new average earth time to be set
    /// @param receivers List of addresses that will receive TimeToken rewards
    /// @param amounts List of amounts of TimeToken to be minted for each receiver
    function moveTime(
        Chronicle[] calldata chronicles, 
        uint256 meanCurrentEarthTime, 
        address[] calldata receivers, 
        uint256[] calldata amounts
    ) external;

    /// @notice returns current block time
    /// @return blockStartEpoch The start epoch of the current block
    /// @return blockEndEpoch The end epoch of the current block
    function getBlockTime() external view returns (uint256 blockStartEpoch, uint256 blockEndEpoch);

    /// @notice Sets the maximum block width
    /// @param _maxBlockWidth The new maximum block width value
    function setMaxBlockWidth(uint256 _maxBlockWidth) external;

    /// @notice Gets the maximum block width
    /// @return The current maximum block width value
    function getMaxBlockWidth() external view returns (uint256);
}
