// SPDX-License-Identifier: MIT
pragma solidity >=0.6.2 <0.9.0;

import {Test} from "forge-std/Test.sol";
import {CallObject, CallObjectStorage} from "../src/TimeTypes.sol";

/// @author philogy <https://github.com/philogy>
contract TimeTypesTest is Test {
    CallObjectStorage callObjStorage;

    function test_setCorrectly(uint256 amount, uint32 gas, address addr, bytes calldata cd) public {
        gas = uint32(bound(gas, 0, (1 << 31) - 1));
        vm.assume(cd.length <= type(uint32).max);

        CallObject memory callObjStart = CallObject({amount: amount, gas: gas, addr: addr, callvalue: cd});

        callObjStorage.store(callObjStart);

        CallObject memory callObjEnd = callObjStorage.load();

        assertEq(callObjStart.amount, callObjEnd.amount, "invalid amount");
        assertEq(callObjStart.gas, callObjEnd.gas, "invalid gas");
        assertEq(callObjStart.addr, callObjEnd.addr, "invalid addr");
        assertEq(callObjStart.callvalue, callObjEnd.callvalue, "invalid callvalue");
    }
}
