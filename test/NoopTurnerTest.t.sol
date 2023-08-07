// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/TimeTurner.sol";
import "../src/NoopTurner.sol";

contract NoopTurnerTest is Test {
    // Counter public counter;

    TimeTurner public timeturner;
    NoopTurner public noopturner;

    function setUp() public {
        timeturner = new TimeTurner();
        noopturner = new NoopTurner(address(timeturner));
    }

    function test_loop() public {
        // check vanilla call, just for fun...
        (bool success, bytes memory ret) = address(noopturner).call{gas: 1000000, value: 0}(abi.encodeWithSignature("vanilla(uint16)", uint16(42)));

        require(success, "vanilla call failed");
        assertEq(abi.decode(ret, (uint16)), uint16(52), "vanilla call returned wrong value");

        // build the call stack
        CallObject[] memory callObjs = new CallObject[](1);
        callObjs[0] = CallObject({
            amount: 0,
            addr: address(noopturner),
            gas: 1000000,
            callvalue: abi.encodeWithSignature("const_loop(uint16)", uint16(42))
        });

        ReturnObject[] memory returnObjs = new ReturnObject[](1);
        // note it always returns 52
        returnObjs[0] = ReturnObject({returnvalue: abi.encode(uint16(52))});

        // call verify
        timeturner.verify(callObjs, returnObjs);
    }
}
