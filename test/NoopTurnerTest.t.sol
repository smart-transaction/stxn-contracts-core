// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

import "forge-std/Test.sol";
import "src/timetravel/CallBreaker.sol";
import "test/examples/NoopTurner.sol";

contract NoopTurnerTest is Test {
    CallBreaker public callbreaker;
    NoopTurner public noopturner;

    function setUp() public {
        callbreaker = new CallBreaker();
        noopturner = new NoopTurner(address(callbreaker));
    }

    function test_loop() public {
        (bool success, bytes memory ret) =
            address(noopturner).call{gas: 1000000, value: 0}(abi.encodeWithSignature("vanilla(uint16)", uint16(42)));

        require(success, "vanilla call failed");
        assertEq(abi.decode(ret, (uint16)), uint16(52), "vanilla call returned wrong value");

        // build the call stack
        CallObject[] memory callObjs = new CallObject[](1);
        callObjs[0] = CallObject({
            amount: 0,
            addr: address(noopturner),
            gas: 1000000,
            callvalue: abi.encodeWithSignature("const_loop()")
        });

        ReturnObject[] memory returnObjs = new ReturnObject[](1);

        returnObjs[0] = ReturnObject({returnvalue: abi.encode(uint16(52))});

        AdditionalData[] memory associatedData = new AdditionalData[](0);

        AdditionalData[] memory hintdices = new AdditionalData[](1);
        hintdices[0] = AdditionalData({key: keccak256(abi.encode(callObjs[0])), value: abi.encode(0)});

        vm.prank(address(0xdeadbeef), address(0xdeadbeef));
        callbreaker.executeAndVerify(
            abi.encode(callObjs), abi.encode(returnObjs), abi.encode(associatedData), abi.encode(hintdices)
        );
    }
}
