// SPDX-License-Identifier: MIT

// NOTE THAT THIS MAY NOT WORK YET! NO TESTS
pragma solidity ^0.8.13;

import "./CallBreaker.sol";

contract PnP {
    address private _callbreakerAddress;

    address[] private addrlist;

    constructor(address callbreakerLocation, uint256 input) {
        _callbreakerAddress = callbreakerLocation;
        // populate addrlist with a hash chain to look "random"
        addrlist.push(address(uint160(uint256(keccak256(abi.encodePacked(input))))));
        for (uint256 i = 1; i < 1000000; i++) {
            addrlist.push(address(uint160(uint256(keccak256(abi.encodePacked(addrlist[i - 1]))))));
        }
    }

    function p(address input, uint256 index) external view returns (bool) {
        if (addrlist[index] == input) {
            return true;
        }
        return false;
    }

    // obviously not np but linear rather than constant time
    function np(address input) external view returns (uint256, bool) {
        uint256 index = 0;
        for (uint256 i = 0; i < 1000000; i++) {
            if (addrlist[i] == input) {
                return (index, true);
            }
        }
        return (0, false);
    }

    function callBreakerNp(address input) external returns (uint256 index) {

        CallObject memory callObj = CallObject({amount: 0, addr: address(this), gas: 1000000, callvalue: abi.encodeWithSignature("const_loop(uint16)", input)});

        // call, hit the fallback.
        (bool success, bytes memory returnvalue) = _callbreakerAddress.call(abi.encode(callObj));

        if (!success) {
            revert("turner CallFailed");
        }

        uint256 returnedvalue = abi.decode(returnvalue, (uint256));

        require(this.p(input, returnedvalue), "callBreakerNp, hint wrong");

        return returnedvalue;
    }
}