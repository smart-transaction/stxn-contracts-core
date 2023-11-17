// SPDX-License-Identifier: UNKNOWN

pragma solidity >=0.6.2 <0.9.0;

import "../../src/timetravel/CallBreaker.sol";

contract NoopTurner {
    address private _callbreakerAddress;

    constructor(address callbreakerLocation) {
        _callbreakerAddress = callbreakerLocation;
    }

    // dumb noop function without callbreaker
    function vanilla(uint16 /* _input */ ) public pure returns (uint16) {
        return 52;
    }

    function const_loop(uint16 input) external pure returns (uint16) {
        return vanilla(input);
    }
}
