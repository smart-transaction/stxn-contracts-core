// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6.2 <0.9.0;

import "forge-std/Test.sol";

import {Laminator} from "src/lamination/Laminator.sol";
import {CallBreaker} from "src/timetravel/CallBreaker.sol";
import {LaminatedProxy} from "src/lamination/LaminatedProxy.sol";
import {CallObjectLib, CallObject} from "src/TimeTypes.sol";
import {Math} from "openzeppelin/utils/math/Math.sol";
import {Dummy} from "./utils/Dummy.sol";

contract LaminatorHarness is Laminator {
    constructor(address _callBreaker) Laminator(_callBreaker) {}

    function harness_getOrCreateProxy(address sender) public returns (address) {
        return _getOrCreateProxy(sender);
    }
}

contract LaminatorTest is Test {
    CallBreaker public callBreaker;
    LaminatorHarness public laminator;

    address randomFriendAddress = address(0xbeefd3ad);

    event ProxyCreated(address indexed owner, address indexed proxyAddress);
    event ProxyPushed(address indexed proxyAddress, CallObject[] callObjs, uint256 sequenceNumber);
    event ProxyExecuted(address indexed proxyAddress, CallObject[] callObjs);
    event CallPushed(CallObject[] callObjs, uint256 sequenceNumber);
    event CallPulled(CallObject[] callObjs, uint256 sequenceNumber);
    event CallExecuted(CallObject callObj);

    event DummyEvent(uint256 arg);

    // @TODO: NotImplemented: Add more unit tests
    function setUp() public {
        callBreaker = new CallBreaker();
        laminator = new LaminatorHarness(address(callBreaker));
    }

    // Existing Proxy and creation Test: Test if the getOrCreateProxy function returns the existing proxy address when one already exists for the sender.
    function testExistingProxy() public {
        address expectedProxyAddress = laminator.computeProxyAddress(address(this));

        vm.expectEmit(true, true, true, true);
        emit ProxyCreated(address(this), expectedProxyAddress);

        assert(laminator.harness_getOrCreateProxy(address(this)) == expectedProxyAddress);
    }

    // Push to Proxy Test: Test if the pushToProxy function correctly delegates a call to the push
    // function of the LaminatedProxy contract. Verify by checking the ProxyPushed event and comparing
    // the emitted sequence number and call object with the expected values.
    function testPushToProxy() public {
        address expectedProxyAddress = laminator.computeProxyAddress(address(this));
        LaminatedProxy proxy = LaminatedProxy(payable(expectedProxyAddress));

        Dummy dummy = new Dummy();

        // push sequence number 0. it should emit 42.
        uint256 val1 = 42;
        CallObject[] memory callObj1 = new CallObject[](1);
        callObj1[0] = CallObject({
            amount: 0,
            addr: address(dummy),
            gas: saneGasLeft(),
            callvalue: abi.encodeWithSignature("emitArg(uint256)", val1)
        });
        bytes memory cData = abi.encode(callObj1);
        vm.expectEmit(true, true, true, true);
        emit ProxyPushed(address(proxy), callObj1, 0);
        emit CallPushed(callObj1, 0);
        uint256 sequenceNumber1 = laminator.pushToProxy(cData, 1);
        assertEq(sequenceNumber1, 0);

        // push sequence number 1. it should emit 43.
        uint256 val2 = 43;
        CallObject[] memory callObj2 = new CallObject[](1);
        callObj2[0] = CallObject({
            amount: 0,
            addr: address(dummy),
            gas: saneGasLeft(),
            callvalue: abi.encodeWithSignature("emitArg(uint256)", val2)
        });
        cData = abi.encode(callObj2);
        vm.expectEmit(true, true, true, true);
        emit ProxyPushed(address(proxy), callObj2, 1);
        emit CallPushed(callObj2, 1);
        uint256 sequenceNumber2 = laminator.pushToProxy(cData, 1);
        assertEq(sequenceNumber2, 1);

        // fastforward a block
        vm.roll(block.number + 1);

        vm.expectEmit(true, true, true, true);
        emit CallPulled(callObj1, 0);
        emit DummyEvent(val1);
        vm.prank(address(callBreaker));
        proxy.pull(0);

        vm.expectEmit(true, true, true, true);
        emit CallPulled(callObj2, 1);
        emit DummyEvent(val2);
        vm.prank(address(callBreaker));
        proxy.pull(1);
    }

    // test delays in pushToProxy- 0 delay is immediately possible
    function testDelayedPushToProxy0delayWorks() public {
        address expectedProxyAddress = laminator.computeProxyAddress(address(this));
        LaminatedProxy proxy = LaminatedProxy(payable(expectedProxyAddress));
        Dummy dummy = new Dummy();

        // push sequence number 0. it should emit 42.
        uint256 val = 42;
        CallObject memory callObj = CallObject({
            amount: 0,
            addr: address(dummy),
            gas: saneGasLeft(),
            callvalue: abi.encodeWithSignature("emitArg(uint256)", val)
        });
        bytes memory cData = abi.encode(callObj);
        uint256 sequenceNumber = laminator.pushToProxy(cData, 0);
        assertEq(sequenceNumber, 0);

        vm.prank(address(callBreaker));
        proxy.pull(0);
    }

    // test delays in pushToProxy- 1 delay with no block rollforward is not possible
    function testDelayedPushToProxy1delayNoRollFails() public {
        address expectedProxyAddress = laminator.computeProxyAddress(address(this));
        LaminatedProxy proxy = LaminatedProxy(payable(expectedProxyAddress));
        Dummy dummy = new Dummy();

        // push sequence number 0. it should emit 42.
        uint256 val = 42;
        CallObject memory callObj = CallObject({
            amount: 0,
            addr: address(dummy),
            gas: saneGasLeft(),
            callvalue: abi.encodeWithSignature("emitArg(uint256)", val)
        });
        bytes memory cData = abi.encode(callObj);
        uint256 sequenceNumber = laminator.pushToProxy(cData, 1);
        assertEq(sequenceNumber, 0);

        // try pulls, make sure it reverts
        vm.prank(address(callBreaker));
        vm.expectRevert(LaminatedProxy.TooEarly.selector);
        proxy.pull(0);
    }

    // test delays in pushToProxy- 3 delay with 1 block rollforward is not possible
    function testDelayedPushToProxy3delay1rollFails() public {
        address expectedProxyAddress = laminator.computeProxyAddress(address(this));
        LaminatedProxy proxy = LaminatedProxy(payable(expectedProxyAddress));
        Dummy dummy = new Dummy();

        // push sequence number 0. it should emit 42.
        uint256 val = 42;
        CallObject memory callObj = CallObject({
            amount: 0,
            addr: address(dummy),
            gas: saneGasLeft(),
            callvalue: abi.encodeWithSignature("emitArg(uint256)", val)
        });
        bytes memory cData = abi.encode(callObj);
        uint256 sequenceNumber = laminator.pushToProxy(cData, 3);
        assertEq(sequenceNumber, 0);

        vm.roll(block.number + 1);

        // try pulls, make sure it reverts
        vm.prank(address(callBreaker));
        vm.expectRevert(LaminatedProxy.TooEarly.selector);
        proxy.pull(0);
    }

    // ensure pushes as a random address when you push directly to someone else's proxy
    function testPushToProxyAsRandomAddress() public {
        address expectedProxyAddress = laminator.computeProxyAddress(address(this));
        LaminatedProxy proxy = LaminatedProxy(payable(expectedProxyAddress));
        laminator.harness_getOrCreateProxy(address(this));
        Dummy dummy = new Dummy();

        uint256 val = 42;
        CallObject memory callObj = CallObject({
            amount: 0,
            addr: address(dummy),
            gas: saneGasLeft(),
            callvalue: abi.encodeWithSignature("emitArg(uint256)", val)
        });
        bytes memory cData = abi.encode(callObj);
        vm.prank(randomFriendAddress);
        vm.expectRevert(LaminatedProxy.NotLaminatorOrProxy.selector);
        proxy.push(cData, 0);
    }

    // ensure pushes as the laminator work
    function testPushToProxyAsLaminator() public {
        address expectedProxyAddress = laminator.computeProxyAddress(address(this));
        LaminatedProxy proxy = LaminatedProxy(payable(expectedProxyAddress));
        laminator.harness_getOrCreateProxy(address(this));

        Dummy dummy = new Dummy();

        uint256 val = 42;
        CallObject[] memory callObj = new CallObject[](1);
        callObj[0] = CallObject({
            amount: 0,
            addr: address(dummy),
            gas: saneGasLeft(),
            callvalue: abi.encodeWithSignature("emitArg(uint256)", val)
        });
        bytes memory cData = abi.encode(callObj);
        vm.prank(address(laminator));
        vm.expectEmit(true, true, true, true);
        emit CallPushed(callObj, 0);
        proxy.push(cData, 1);
    }

    // test that double-pulling the same sequence number does not work
    function testDoublePull() public {
        address expectedProxyAddress = laminator.computeProxyAddress(address(this));
        LaminatedProxy proxy = LaminatedProxy(payable(expectedProxyAddress));
        Dummy dummy = new Dummy();
        // push once
        uint256 val = 42;
        CallObject[] memory callObj = new CallObject[](1);
        callObj[0] = CallObject({
            amount: 0,
            addr: address(dummy),
            gas: saneGasLeft(),
            callvalue: abi.encodeWithSignature("emitArg(uint256)", val)
        });
        bytes memory cData = abi.encode(callObj);
        uint256 sequenceNumber = laminator.pushToProxy(cData, 0);
        assertEq(sequenceNumber, 0);

        // pull once
        vm.prank(address(callBreaker));
        proxy.pull(0);

        // and try to pull again
        vm.prank(address(callBreaker));
        vm.expectRevert(LaminatedProxy.AlreadyExecuted.selector);
        proxy.pull(0);
    }

    // test that a call that reverts revert the transaction
    function testRevertCall() public {
        address expectedProxyAddress = laminator.computeProxyAddress(address(this));
        LaminatedProxy proxy = LaminatedProxy(payable(expectedProxyAddress));
        laminator.harness_getOrCreateProxy(address(this));
        Dummy dummy = new Dummy();

        CallObject[] memory callObj = new CallObject[](1);
        callObj[0] = CallObject({
            amount: 0,
            addr: address(dummy),
            gas: saneGasLeft(),
            callvalue: abi.encodeWithSignature("reverter()")
        });
        bytes memory cData = abi.encode(callObj);
        uint256 sequenceNumber = laminator.pushToProxy(cData, 1);
        assertEq(sequenceNumber, 0);

        vm.roll(block.number + 1);

        vm.prank(address(callBreaker));
        vm.expectRevert(LaminatedProxy.CallFailed.selector);
        proxy.pull(0);
    }

    // ensure executions called directly to proxy as a random address don't work
    function testExecuteAsRandomAddress() public {
        address expectedProxyAddress = laminator.computeProxyAddress(address(this));
        LaminatedProxy proxy = LaminatedProxy(payable(expectedProxyAddress));
        laminator.harness_getOrCreateProxy(address(this));
        Dummy dummy = new Dummy();
        CallObject memory callObj = CallObject({
            amount: 0,
            addr: address(dummy),
            gas: saneGasLeft(),
            callvalue: abi.encodeWithSignature("emitArg(uint256)", 42)
        });
        bytes memory cData = abi.encode(callObj);

        // pretend to be a random address and call directly, should fail
        vm.prank(randomFriendAddress);
        vm.expectRevert(LaminatedProxy.NotLaminator.selector);
        proxy.execute(cData);
    }

    // ensure executions called into proxy directly as the laminator do work
    function testExecuteAsLaminator() public {
        address expectedProxyAddress = laminator.computeProxyAddress(address(this));
        LaminatedProxy proxy = LaminatedProxy(payable(expectedProxyAddress));
        laminator.harness_getOrCreateProxy(address(this));
        Dummy dummy = new Dummy();
        CallObject[] memory callObjs = new CallObject[](1);
        callObjs[0] = CallObject({
            amount: 0,
            addr: address(dummy),
            gas: saneGasLeft(),
            callvalue: abi.encodeWithSignature("emitArg(uint256)", 42)
        });
        bytes memory cData = abi.encode(callObjs);

        // pretend to be the laminator and call directly, should work
        vm.prank(address(laminator));
        vm.expectEmit(true, true, true, true);
        emit CallExecuted(callObjs[0]);
        proxy.execute(cData);
    }

    // ensure executions as the owner directly into the proxy contract do NOT work
    function testExecuteAsOwner() public {
        address me = address(this);
        address expectedProxyAddress = laminator.computeProxyAddress(address(this));
        LaminatedProxy proxy = LaminatedProxy(payable(expectedProxyAddress));
        laminator.harness_getOrCreateProxy(address(this));
        Dummy dummy = new Dummy();
        CallObject memory callObj = CallObject({
            amount: 0,
            addr: address(dummy),
            gas: saneGasLeft(),
            callvalue: abi.encodeWithSignature("emitArg(uint256)", 42)
        });
        bytes memory cData = abi.encode(callObj);

        vm.prank(me);
        vm.expectRevert(LaminatedProxy.NotLaminator.selector);
        proxy.execute(cData);
    }

    /// cleanupStorage tests
    /// Goal: use a 'use after free' function -- question for when things are deleted
    /// Can only be deleted ... when? Iff executed == init == true? maybe by the owner?
    /// Concern: Laminator can be done with pull before callBreaker is done with verify
    /// Pull --> clean storage --> executed check --> ??? (how to force cleanup deletion to be last)
    /// Deletion should be last? --> how to force this?
    /// Change array to mapping of job schedule
    function testExecuteBeforeDeleteLogic() public view {
        console.logString("This function has not been implemented yet.");
    }

    function testCheckOFAC() public view {
        console.logString("This function has not been implemented yet.");
    }

    function testCheckAudited() public view {
        console.logString("This function has not been implemented yet.");
    }

    // ensure executions as random address through the laminator do not work
    function testExecuteAsRandomAddressFromLaminator() public {
        address expectedProxyAddress = laminator.computeProxyAddress(address(this));
        LaminatedProxy proxy = LaminatedProxy(payable(expectedProxyAddress));
        laminator.harness_getOrCreateProxy(address(this));
        Dummy dummy = new Dummy();
        CallObject memory callObj = CallObject({
            amount: 0,
            addr: address(dummy),
            gas: saneGasLeft(),
            callvalue: abi.encodeWithSignature("emitArg(uint256)", 42)
        });
        bytes memory cData = abi.encode(callObj);

        // pretend to be a random address and call directly, should fail
        vm.prank(randomFriendAddress);
        vm.expectRevert(LaminatedProxy.NotLaminator.selector);
        proxy.execute(cData);
    }

    // ensure executions as laminator through the laminator do work
    function testExecuteAsLaminatorAddressFromLaminator() public {
        address expectedProxyAddress = laminator.computeProxyAddress(address(this));
        LaminatedProxy proxy = LaminatedProxy(payable(expectedProxyAddress));
        laminator.harness_getOrCreateProxy(address(this));
        Dummy dummy = new Dummy();
        CallObject memory callObj = CallObject({
            amount: 0,
            addr: address(dummy),
            gas: saneGasLeft(),
            callvalue: abi.encodeWithSignature("emitArg(uint256)", 42)
        });
        bytes memory cData = abi.encode(callObj);

        // pretend to be laminator and call directly, should succeed
        vm.prank(address(laminator));
        proxy.execute(cData);
    }

    function saneGasLeft() internal view returns (uint256) {
        return Math.min(gasleft(), CallObjectLib.MAX_PACKED_GAS);
    }
}
