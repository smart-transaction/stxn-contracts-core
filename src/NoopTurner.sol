// SPDX-License-Identifier: UNKNOWN

pragma solidity ^0.8.20;

import "./TimeTurner.sol";

contract NoopTurner {
    address timeturner_address;

    constructor(address timeturner_location) {
        timeturner_address = timeturner_location;
    }

    function const_loop(uint16 input) external returns (uint16) {
        // call yourself into the turner. (what??)
        // why would you ever do this?
        CallObject memory callObj = CallObject({amount: 0, addr: address(this), gas: 1000000, callvalue: abi.encodeWithSignature("const_loop(uint16)", input)});

        // call, hit the fallback.
        (bool success, bytes memory returnvalue) = timeturner_address.call(abi.encode(callObj));

        if (!success) {
            revert("turner CallFailed");
        }

        // this one just returns whatever it gets from the turner.
        return abi.decode(returnvalue, (uint16));
    }

    // dumb noop function without timeturner
    function vanilla(uint16 _input) external pure returns (uint16) {
        return 52;
    }
}
