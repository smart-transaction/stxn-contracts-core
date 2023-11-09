// SPDX-License-Identifier: UNKNOWN

pragma solidity >=0.6.2 <0.9.0;

import "../../src/timetravel/CallBreaker.sol";

contract NoopTurner {
    address private _callbreakerAddress;

    constructor(address callbreakerLocation) {
        _callbreakerAddress = callbreakerLocation;
    }

    function const_loop(uint16 input) external returns (uint16) {
        CallObject memory callObj = CallObject({
            amount: 0,
            addr: address(this),
            gas: 1000000,
            callvalue: abi.encodeWithSignature("const_loop(uint16)", input)
        });

        CallObjectWithIndex memory callObjWithIndex = CallObjectWithIndex({callObj: callObj, index: 0, executed: false});

        // call, hit the fallback.
        (bool success, bytes memory returnvalue) = _callbreakerAddress.call(abi.encode(callObjWithIndex));

        if (!success) {
            revert("turner CallFailed");
        }

        // this one just returns whatever it gets from the turner.
        return abi.decode(returnvalue, (uint16));
    }

    // dumb noop function without callbreaker
    function vanilla(uint16 _input) external pure returns (uint16) {
        return 52;
    }
}
