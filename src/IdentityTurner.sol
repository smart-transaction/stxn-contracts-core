// SPDX-License-Identifier: UNKNOWN

pragma solidity ^0.8.13;

import "./TimeTurner.sol";

contract IdentityTurner {
    address timeturner_address;

    constructor(address timeturner_location) {
        timeturner_address = timeturner_location;
    }

    function const_loop(uint16 input) external returns (uint16) {
        CallObject memory callObj = CallObject({amount: 0, addr: address(this), gas: 1000000, callvalue: abi.encodeWithSignature("const_loop(uint16)", input)});

        (bool success, bytes memory returnvalue) = timeturner_address.call(abi.encode(callObj));

        if (!success) {
            revert("turner CallFailed");
        }

        // decode ret, return it
        return abi.decode(returnvalue, (uint16));
    }

    function vanilla(uint16 input) external pure returns (uint16) {
        return input;
    }
}
