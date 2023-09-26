// SPDX-License-Identifier: MIT

pragma solidity >=0.6.2 <0.9.0;

import "../timetravel/CallBreaker.sol";

contract TemporalStates {
    address private _callbreakerAddress;
    constructor(address callbreakerLocation) {
        _callbreakerAddress = callbreakerLocation;
    }

    function entryPoint(uint256 blockTime, bytes memory input) external pure returns (bool) {
        return _rightTime(blockTime) && _isVulnerable(input);
    }

    function _rightTime(uint256 blockTime) internal pure returns (bool) {
        return blockTime == 3;
    }

    function _isVulnerable(bytes memory input) internal pure returns (bool) {
        bytes memory vulnString = "vulnerable";
        return keccak256(vulnString) == keccak256(input);
    }
}
