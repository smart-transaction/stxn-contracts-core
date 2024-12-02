// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

interface IBlockTime {
    function updateTime(uint256 timestamp) external;

    function latestTimestamp() external view returns (uint256);
}
