// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.6.2 <0.9.0;

contract CronTwoCounter {
    mapping(address => uint256) private _counters;

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
