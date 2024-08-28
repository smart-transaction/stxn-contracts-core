// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

import "forge-std/Test.sol";

import {Laminator} from "src/lamination/Laminator.sol";
import {CallBreaker} from "src/timetravel/CallBreaker.sol";
import {LaminatedProxy} from "src/lamination/LaminatedProxy.sol";
import {CallObjectLib, CallObject, CallObjectHolder, ReturnObject} from "src/TimeTypes.sol";
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
    Dummy public dummy;
    LaminatorHarness public laminator;
    LaminatedProxy public proxy;
    address public expectedProxyAddress;

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
        expectedProxyAddress = laminator.computeProxyAddress(address(this));
        proxy = LaminatedProxy(payable(expectedProxyAddress));
        dummy = new Dummy();
    }

    // Existing Proxy and creation Test: Test if the getOrCreateProxy function returns the existing proxy address when one already exists for the sender.
    function testExistingProxy() public {
        vm.expectEmit(true, true, true, true);
        emit ProxyCreated(address(this), expectedProxyAddress);

        assert(laminator.harness_getOrCreateProxy(address(this)) == expectedProxyAddress);
    }

    // Push to Proxy Test: Test if the pushToProxy function correctly delegates a call to the push
    // function of the LaminatedProxy contract. Verify by checking the ProxyPushed event and comparing
    // the emitted sequence number and call object with the expected values.
    function testPushToProxy() public {
        uint256 nextSeq = laminator.getNextSeqNumber();
        assertEq(nextSeq, 0);

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

        nextSeq = laminator.getNextSeqNumber();
        assertEq(nextSeq, 1);

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

        nextSeq = laminator.getNextSeqNumber();
        assertEq(nextSeq, 2);

        // fastforward a block
        vm.roll(block.number + 1);

        vm.expectEmit(true, true, true, true);
        emit CallPulled(callObj1, 0);
        emit DummyEvent(val1);
        vm.prank(address(callBreaker), address(callBreaker));
        proxy.pull(0);

        vm.expectEmit(true, true, true, true);
        emit CallPulled(callObj2, 1);
        emit DummyEvent(val2);
        vm.prank(address(callBreaker), address(callBreaker));
        proxy.pull(1);
    }

    // test delays in pushToProxy- 0 delay is immediately possible
    function testDelayedPushToProxy0delayWorks() public {
        // push sequence number 0. it should emit 42.
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

        vm.prank(address(callBreaker), address(callBreaker));
        // try pulls as a random address, make sure the events were emitted
        vm.expectEmit(true, true, true, true);
        emit CallPulled(callObj, 0);
        proxy.pull(0);
    }

    // test delays in pushToProxy- 1 delay with no block rollforward is not possible
    function testDelayedPushToProxy1delayNoRollFails() public {
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
        vm.prank(address(callBreaker), address(callBreaker));
        vm.expectRevert(LaminatedProxy.TooEarly.selector);
        proxy.pull(0);
    }

    // test delays in pushToProxy- 3 delay with 1 block rollforward is not possible
    function testDelayedPushToProxy3delay1rollFails() public {
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
        vm.prank(address(callBreaker), address(callBreaker));
        vm.expectRevert(LaminatedProxy.TooEarly.selector);
        proxy.pull(0);
    }

    // ensure pushes as a random address when you push directly to someone else's proxy
    function testPushToProxyAsRandomAddress() public {
        laminator.harness_getOrCreateProxy(address(this));

        uint256 val = 42;
        CallObject memory callObj = CallObject({
            amount: 0,
            addr: address(dummy),
            gas: saneGasLeft(),
            callvalue: abi.encodeWithSignature("emitArg(uint256)", val)
        });
        bytes memory cData = abi.encode(callObj);
        vm.prank(randomFriendAddress, randomFriendAddress);
        vm.expectRevert(LaminatedProxy.NotLaminatorOrProxy.selector);
        proxy.push(cData, 0);
    }

    // ensure pushes as the laminator work
    function testPushToProxyAsLaminator() public {
        laminator.harness_getOrCreateProxy(address(this));

        uint256 val = 42;
        CallObject[] memory callObj = new CallObject[](1);
        callObj[0] = CallObject({
            amount: 0,
            addr: address(dummy),
            gas: saneGasLeft(),
            callvalue: abi.encodeWithSignature("emitArg(uint256)", val)
        });
        bytes memory cData = abi.encode(callObj);
        vm.prank(address(laminator), address(laminator));
        vm.expectEmit(true, true, true, true);
        emit CallPushed(callObj, 0);
        proxy.push(cData, 1);
    }

    // test cancel pending call
    function testCancelPending() public {
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
        vm.prank(address(randomFriendAddress), address(randomFriendAddress));
        vm.expectRevert(LaminatedProxy.NotCallBreaker.selector);
        proxy.pull(0);
    }

    // test cancel pending call
    function testCancelAllPending() public {
        uint256 val = 42;
        // push twice
        CallObject[] memory callObj1 = new CallObject[](1);
        callObj1[0] = CallObject({
            amount: 0,
            addr: address(dummy),
            gas: saneGasLeft(),
            callvalue: abi.encodeWithSignature("emitArg(uint256)", val)
        });
        bytes memory cData = abi.encode(callObj1);
        laminator.pushToProxy(cData, 0);

        CallObject[] memory callObj2 = new CallObject[](1);
        callObj2[0] = CallObject({
            amount: 0,
            addr: address(dummy),
            gas: saneGasLeft(),
            callvalue: abi.encodeWithSignature("emitArg(uint256)", val)
        });
        cData = abi.encode(callObj2);
        laminator.pushToProxy(cData, 0);

        proxy.cancelAllPending();

        vm.prank(address(callBreaker), address(callBreaker));
        vm.expectRevert(LaminatedProxy.AlreadyExecuted.selector);
        proxy.pull(0);

        vm.prank(address(callBreaker), address(callBreaker));
        vm.expectRevert(LaminatedProxy.AlreadyExecuted.selector);
        proxy.pull(1);
    }

    // ensure pulls from proxy as a random address reverts
    function testPullFromProxyAsRandomAddress() public {
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
        vm.prank(address(randomFriendAddress), address(randomFriendAddress));
        vm.expectRevert(LaminatedProxy.NotCallBreaker.selector);
        proxy.pull(0);
    }

    // test that double-pulling the same sequence number does not work
    function testDoublePull() public {
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
        vm.prank(address(callBreaker), address(callBreaker));
        proxy.pull(0);

        // and try to pull again
        vm.prank(address(callBreaker), address(callBreaker));
        vm.expectRevert(LaminatedProxy.AlreadyExecuted.selector);
        proxy.pull(0);
    }

    function testUninitializedPull() public {
        // push once
        uint256 val = 42;
        CallObject[] memory callObj = new CallObject[](2);
        callObj[0] = CallObject({
            amount: 0,
            addr: address(dummy),
            gas: saneGasLeft(),
            callvalue: abi.encodeWithSignature("emitArg(uint256)", val)
        });
        callObj[1] = CallObject({
            amount: 0,
            addr: address(dummy),
            gas: saneGasLeft(),
            callvalue: abi.encodeWithSignature("emitArg(uint256)", val)
        });
        bytes memory cData = abi.encode(callObj);
        uint256 sequenceNumber = laminator.pushToProxy(cData, 0);
        assertEq(sequenceNumber, 0);

        // try to pull out of order
        vm.prank(address(callBreaker), address(callBreaker));
        vm.expectRevert(LaminatedProxy.Uninitialized.selector);
        proxy.pull(1);
    }

    // test that a call that reverts revert the transaction
    function testRevertCall() public {
        laminator.harness_getOrCreateProxy(address(this));

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

        vm.prank(address(callBreaker), address(callBreaker));
        vm.expectRevert(LaminatedProxy.CallFailed.selector);
        proxy.pull(0);
    }

    // ensure executions called directly to proxy as a random address don't work
    function testExecuteAsRandomAddress() public {
        laminator.harness_getOrCreateProxy(address(this));
        CallObject memory callObj = CallObject({
            amount: 0,
            addr: address(dummy),
            gas: saneGasLeft(),
            callvalue: abi.encodeWithSignature("emitArg(uint256)", 42)
        });
        bytes memory cData = abi.encode(callObj);

        // pretend to be a random address and call directly, should fail
        vm.prank(randomFriendAddress);
        vm.expectRevert(LaminatedProxy.NotOwner.selector);
        proxy.execute(cData);
    }

    // ensure executions called into proxy directly as the laminator do work
    function testExecuteAsLaminator() public {
        laminator.harness_getOrCreateProxy(address(this));
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
        vm.expectRevert(LaminatedProxy.NotOwner.selector);
        proxy.execute(cData);
    }

    // ensure executions as the owner directly into the proxy contract do NOT work
    function testExecuteAsOwner() public {
        laminator.harness_getOrCreateProxy(address(this));
        CallObject memory callObj = CallObject({
            amount: 0,
            addr: address(dummy),
            gas: saneGasLeft(),
            callvalue: abi.encodeWithSignature("emitArg(uint256)", 42)
        });

        bytes memory cData = abi.encode(callObj);
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
        laminator.harness_getOrCreateProxy(address(this));
        CallObject memory callObj = CallObject({
            amount: 0,
            addr: address(dummy),
            gas: saneGasLeft(),
            callvalue: abi.encodeWithSignature("emitArg(uint256)", 42)
        });
        bytes memory cData = abi.encode(callObj);

        // pretend to be a random address and call directly, should fail
        vm.prank(randomFriendAddress);
        vm.expectRevert(LaminatedProxy.NotOwner.selector);
        proxy.execute(cData);
    }

    // ensure executions as laminator through the laminator do work
    function testExecuteAsLaminatorAddressFromLaminator() public {
        laminator.harness_getOrCreateProxy(address(this));
        CallObject memory callObj = CallObject({
            amount: 0,
            addr: address(dummy),
            gas: saneGasLeft(),
            callvalue: abi.encodeWithSignature("emitArg(uint256)", 42)
        });

        bytes memory cData = abi.encode(callObj);
        proxy.execute(cData);
    }

    function testGetExecutingCallObject() public {
        laminator.harness_getOrCreateProxy(address(this));
        CallObject[] memory callObj = new CallObject[](1);
        callObj[0] = CallObject({
            amount: 0,
            addr: address(proxy),
            gas: saneGasLeft(),
            callvalue: abi.encodeWithSignature("getExecutingCallObject()")
        });
        bytes memory cData = abi.encode(callObj);
        laminator.pushToProxy(cData, 0);

        vm.prank(address(callBreaker), address(callBreaker));
        bytes memory returnValue = proxy.pull(0);
        ReturnObject[] memory returnObj = abi.decode(returnValue, (ReturnObject[]));
        CallObject memory returnCallObject = abi.decode(returnObj[0].returnvalue, (CallObject));
        assertEq(abi.encode(returnCallObject), abi.encode(callObj[0]));
    }

    function testGetExecutingCallObjectHolder() public {
        laminator.harness_getOrCreateProxy(address(this));
        CallObject[] memory callObj = new CallObject[](1);
        callObj[0] = CallObject({
            amount: 0,
            addr: address(proxy),
            gas: saneGasLeft(),
            callvalue: abi.encodeWithSignature("getExecutingCallObjectHolder()")
        });
        bytes memory cData = abi.encode(callObj);
        laminator.pushToProxy(cData, 0);

        vm.prank(address(callBreaker), address(callBreaker));
        bytes memory returnValue = proxy.pull(0);
        ReturnObject[] memory returnObj = abi.decode(returnValue, (ReturnObject[]));
        CallObjectHolder memory returnCallObjectHolder = abi.decode(returnObj[0].returnvalue, (CallObjectHolder));
        assertEq(abi.encode(returnCallObjectHolder.callObjs[0]), abi.encode(callObj[0]));
    }

    function testCleanupLaminatorStorage() public {
        laminator.harness_getOrCreateProxy(address(this));
        uint256 val = 42;
        // push twice
        CallObject[] memory callObj1 = new CallObject[](1);
        callObj1[0] = CallObject({
            amount: 0,
            addr: address(dummy),
            gas: saneGasLeft(),
            callvalue: abi.encodeWithSignature("emitArg(uint256)", val)
        });
        bytes memory cData = abi.encode(callObj1);
        uint256[] memory sequenceNumber = new uint256[](1);
        sequenceNumber[0] = laminator.pushToProxy(cData, 0);

        // clean before any pull changess nothing
        proxy.cleanupLaminatorStorage(sequenceNumber);
        CallObjectHolder memory holder = proxy.deferredCalls(0);
        assertEq(holder.callObjs.length, callObj1.length);

        // pull one
        vm.prank(address(callBreaker), address(callBreaker));
        proxy.pull(0);

        // clean after pull clears executed call objects
        proxy.cleanupLaminatorStorage(sequenceNumber);
        holder = proxy.deferredCalls(0);
        assertEq(holder.callObjs.length, 0);
    }

    function saneGasLeft() internal view returns (uint256) {
        return Math.min(gasleft(), CallObjectLib.MAX_PACKED_GAS);
    }
}
