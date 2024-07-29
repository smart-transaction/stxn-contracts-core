// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.26;

import "../../src/timetravel/SmarterContract.sol";

contract CronCounter is SmarterContract {
    mapping(address => uint256) private _counters;

    constructor(address _callbreaker) SmarterContract(_callbreaker) {}

    function increment() public {
        _counters[msg.sender]++;
    }

    function getCount(address addr) public view returns (uint256) {
        return _counters[addr];
    }

    function shouldContinue() public view returns (bool) {
        if (_counters[msg.sender] > 3) {
            return false;
        }
        return true;
    }
}
