// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6.2 <0.9.0;

import "forge-std/Test.sol";
//import {VmSafe} from "forge-std/Vm.sol";

import "../src/lamination/Laminator.sol";
import "../src/lamination/LaminatedProxy.sol";
import "../src/examples/Dummy.sol";

contract LaminatorTest is Test {
    Laminator public laminator;

    address randomFriendAddress = address(0xbeefd3ad);

    event ProxyCreated(address indexed owner, address indexed proxyAddress);
    event ProxyPushed(address indexed proxyAddress, CallObject callObj, uint256 sequenceNumber);
    event ProxyExecuted(address indexed proxyAddress, CallObject callObj);
    event CallPushed(CallObject callObj, uint256 sequenceNumber);
    event CallPulled(CallObject callObj, uint256 sequenceNumber);
    event CallExecuted(CallObject callObj);

    event DummyEvent(uint256 arg);

    function setUp() public {
        laminator = new Laminator();
    }

    // - Proxy Creation Test: Test if the getOrCreateProxy function creates a new
    // proxy when one does not exist for the sender. Verify by checking the ProxyCreated
    // event and comparing the emitted proxy address with the computed proxy address.
    function testProxyCreation() public {
        vm.expectEmit(true, true, true, true);
        address proxyAddress = laminator.getOrCreateProxy();
        address expectedProxyAddress = laminator.computeProxyAddress(address(this));
        assertEq(proxyAddress, expectedProxyAddress);
    }

    // - Existing Proxy Test: Test if the getOrCreateProxy function returns the existing proxy address when one already exists for the sender.
    function testExistingProxy() public {
        address expectedProxyAddress = laminator.computeProxyAddress(address(this));

        vm.expectEmit(true, true, true, true);
        emit ProxyCreated(address(this), expectedProxyAddress);
        address proxyAddress1 = laminator.getOrCreateProxy();

        assertEq(proxyAddress1, expectedProxyAddress);
        assert(address(proxyAddress1).code.length > 0);

        address proxyAddress2 = laminator.getOrCreateProxy();
        assertEq(proxyAddress1, proxyAddress2);
    }

    //- Push to Proxy Test: Test if the pushToProxy function correctly delegates a call to the push
    // function of the LaminatedProxy contract. Verify by checking the ProxyPushed event and comparing
    // the emitted sequence number and call object with the expected values.
    function testPushToProxy() public {
        LaminatedProxy proxy = LaminatedProxy(payable(laminator.getOrCreateProxy()));

        Dummy dummy = new Dummy();

        // push sequence number 0. it should emit 42.
        uint256 val1 = 42;
        CallObject memory callObj1 = CallObject({
            amount: 0,
            addr: address(dummy),
            gas: gasleft(),
            callvalue: abi.encodeWithSignature("emitArg(uint256)", val1)
        });
        bytes memory cData = abi.encode(callObj1);
        vm.expectEmit(true, true, true, true);
        emit ProxyPushed(address(proxy), callObj1, 0);
        emit CallPushed(callObj1, 0);
        uint256 sequenceNumber1 = laminator.pushToProxy(cData);
        assertEq(sequenceNumber1, 0);

        // push sequence number 1. it should emit 43.
        uint256 val2 = 43;
        CallObject memory callObj2 = CallObject({
            amount: 0,
            addr: address(dummy),
            gas: gasleft(),
            callvalue: abi.encodeWithSignature("emitArg(uint256)", val2)
        });
        cData = abi.encode(callObj2);
        vm.expectEmit(true, true, true, true);
        emit ProxyPushed(address(proxy), callObj2, 1);
        emit CallPushed(callObj2, 1);
        uint256 sequenceNumber2 = laminator.pushToProxy(cData);
        assertEq(sequenceNumber2, 1);

        // fastforward a block
        vm.warp(block.number + 1);

        vm.expectEmit(true, true, true, true);
        emit CallPulled(callObj1, 0);
        emit DummyEvent(val1);
        vm.prank(randomFriendAddress);
        proxy.pull(0);

        vm.expectEmit(true, true, true, true);
        emit CallPulled(callObj2, 1);
        emit DummyEvent(val2);
        vm.prank(randomFriendAddress);
        proxy.pull(0);
    }

    // test delays in pushToProxy- 0 delay is immediately possible
    function testDelayedPushToProxy0delayWorks() public {
        LaminatedProxy proxy = LaminatedProxy(payable(laminator.getOrCreateProxy()));
        Dummy dummy = new Dummy();

        // push sequence number 0. it should emit 42.
        uint256 val = 42;
        CallObject memory callObj = CallObject({
            amount: 0,
            addr: address(dummy),
            gas: gasleft(),
            callvalue: abi.encodeWithSignature("emitArg(uint256)", val)
        });
        bytes memory cData = abi.encode(callObj);
        uint256 sequenceNumber = laminator.pushToProxy(cData, 0);
        assertEq(sequenceNumber, 0);

        // try pulls as a random address, make sure the events were emitted
        vm.prank(randomFriendAddress);
        proxy.pull(0);
    }

    // test delays in pushToProxy- 1 delay with no block warp is not possible
    function testDelayedPushToProxy1delayNoWarpFails() public {
        LaminatedProxy proxy = LaminatedProxy(payable(laminator.getOrCreateProxy()));
        Dummy dummy = new Dummy();

        // push sequence number 0. it should emit 42.
        uint256 val = 42;
        CallObject memory callObj = CallObject({
            amount: 0,
            addr: address(dummy),
            gas: gasleft(),
            callvalue: abi.encodeWithSignature("emitArg(uint256)", val)
        });
        bytes memory cData = abi.encode(callObj);
        uint256 sequenceNumber = laminator.pushToProxy(cData, 1);
        assertEq(sequenceNumber, 0);

        // try pulls as a random address, make sure the events were emitted
        vm.prank(randomFriendAddress);
        try proxy.pull(0) {
            assert(false);
        } catch Error(string memory reason) {
            assertEq(reason, "Proxy: Too early to pull this sequence number");
        }
    }

    // test delays in pushToProxy- 3 delay with 1 block warp is not possible
    function testDelayedPushToProxy3delay1WarpFails() public {
        LaminatedProxy proxy = LaminatedProxy(payable(laminator.getOrCreateProxy()));
        Dummy dummy = new Dummy();

        // push sequence number 0. it should emit 42.
        uint256 val = 42;
        CallObject memory callObj = CallObject({
            amount: 0,
            addr: address(dummy),
            gas: gasleft(),
            callvalue: abi.encodeWithSignature("emitArg(uint256)", val)
        });
        bytes memory cData = abi.encode(callObj);
        uint256 sequenceNumber = laminator.pushToProxy(cData, 3);
        assertEq(sequenceNumber, 0);

        vm.warp(block.number + 1);

        // try pulls as a random address, make sure the events were emitted
        vm.prank(randomFriendAddress);
        try proxy.pull(0) {
            assert(false);
        } catch Error(string memory reason) {
            assertEq(reason, "Proxy: Too early to pull this sequence number");
        }
    }

    // ensure pushes as a random address when you push directly to someone else's proxy
    function testPushToProxyAsRandomAddress() public {
        LaminatedProxy proxy = LaminatedProxy(payable(laminator.getOrCreateProxy()));
        Dummy dummy = new Dummy();

        uint256 val = 42;
        CallObject memory callObj = CallObject({
            amount: 0,
            addr: address(dummy),
            gas: gasleft(),
            callvalue: abi.encodeWithSignature("emitArg(uint256)", val)
        });
        bytes memory cData = abi.encode(callObj);
        vm.prank(randomFriendAddress);
        try proxy.push(cData) {
            assert(false);
        } catch Error(string memory reason) {
            assertEq(reason, "Proxy: Not the owner");
        }
    }

    // ensure pushes as the laminator don't work
    function testPushToProxyAsLaminator() public {
        LaminatedProxy proxy = LaminatedProxy(payable(laminator.getOrCreateProxy()));
        Dummy dummy = new Dummy();

        uint256 val = 42;
        CallObject memory callObj = CallObject({
            amount: 0,
            addr: address(dummy),
            gas: gasleft(),
            callvalue: abi.encodeWithSignature("emitArg(uint256)", val)
        });
        bytes memory cData = abi.encode(callObj);
        vm.prank(address(laminator));
        try proxy.push(cData) {
            assert(false);
        } catch Error(string memory reason) {
            assertEq(reason, "Proxy: Not the owner");
        }
    }

    // test that double-pulling the same sequence number does not work
    function testDoublePull() public {
        LaminatedProxy proxy = LaminatedProxy(payable(laminator.getOrCreateProxy()));
        Dummy dummy = new Dummy();
        // push once
        uint256 val = 42;
        CallObject memory callObj = CallObject({
            amount: 0,
            addr: address(dummy),
            gas: gasleft(),
            callvalue: abi.encodeWithSignature("emitArg(uint256)", val)
        });
        bytes memory cData = abi.encode(callObj);
        uint256 sequenceNumber = laminator.pushToProxy(cData, 0);
        assertEq(sequenceNumber, 0);

        // pull once
        vm.prank(randomFriendAddress);
        proxy.pull(0);

        // and try to pull again
        try proxy.pull(0) {
            assert(false);
        } catch Error(string memory reason) {
            assertEq(reason, "Proxy: Invalid sequence number");
        }
    }

    // test that uninitialized sequence numbers cannot be pulled
    function testUninitializedPull() public {
        LaminatedProxy proxy = LaminatedProxy(payable(laminator.getOrCreateProxy()));
        try proxy.pull(0) {
            assert(false);
        } catch Error(string memory reason) {
            assertEq(reason, "Proxy: Invalid sequence number");
        }
    }

    // test that a call that reverts revert the transaction
    function testRevertCall() public {
        LaminatedProxy proxy = LaminatedProxy(payable(laminator.getOrCreateProxy()));
        Dummy dummy = new Dummy();

        CallObject memory callObj = CallObject({
            amount: 0,
            addr: address(dummy),
            gas: gasleft(),
            callvalue: abi.encodeWithSignature("reverter()")
        });
        bytes memory cData = abi.encode(callObj);
        uint256 sequenceNumber = laminator.pushToProxy(cData);
        assertEq(sequenceNumber, 0);

        vm.warp(block.number + 1);

        vm.prank(randomFriendAddress);
        try proxy.pull(0) {
            assert(false);
        } catch Error(string memory reason) {
            assertEq(reason, "Dummy: revert");
        }
    }

    // ensure executions as a random address don't work
    function testExecuteAsRandomAddress() public {
        LaminatedProxy proxy = LaminatedProxy(payable(laminator.getOrCreateProxy()));
        Dummy dummy = new Dummy();
        CallObject memory callObj = CallObject({
            amount: 0,
            addr: address(dummy),
            gas: gasleft(),
            callvalue: abi.encodeWithSignature("emitArg(uint256)", 42)
        });
        bytes memory cData = abi.encode(callObj);

        // pretend to be a random address and call directly, should fail
        vm.prank(randomFriendAddress);
        try proxy.execute(cData) {
            assert(false);
        } catch Error(string memory reason) {
            assertEq(reason, "Proxy: Not the owner");
        }
    }

    // ensure executions as the laminator don't work
    function testExecuteAsLaminator() public {
        LaminatedProxy proxy = LaminatedProxy(payable(laminator.getOrCreateProxy()));
        Dummy dummy = new Dummy();
        CallObject memory callObj = CallObject({
            amount: 0,
            addr: address(dummy),
            gas: gasleft(),
            callvalue: abi.encodeWithSignature("emitArg(uint256)", 42)
        });
        bytes memory cData = abi.encode(callObj);

        // pretend to be the laminator and call directly, should fail
        vm.prank(address(laminator));
        try proxy.execute(cData) {
            assert(false);
        } catch Error(string memory reason) {
            assertEq(reason, "Proxy: Not the owner");
        }
    }

    // ensure executions as the owner directly into this contract do work
    function testExecuteAsOwner() public {
        LaminatedProxy proxy = LaminatedProxy(payable(laminator.getOrCreateProxy()));
        Dummy dummy = new Dummy();
        CallObject memory callObj = CallObject({
            amount: 0,
            addr: address(dummy),
            gas: gasleft(),
            callvalue: abi.encodeWithSignature("emitArg(uint256)", 42)
        });
        bytes memory cData = abi.encode(callObj);

        // check emissions, this should work
        vm.expectEmit(true, true, true, true);
        emit CallExecuted(callObj);
        proxy.execute(cData);
    }

    // ensure executions as the owner from the laminator do work
    function testExecuteAsOwnerFromLaminator() public {
        LaminatedProxy proxy = LaminatedProxy(payable(laminator.getOrCreateProxy()));
        Dummy dummy = new Dummy();
        CallObject memory callObj = CallObject({
            amount: 0,
            addr: address(dummy),
            gas: gasleft(),
            callvalue: abi.encodeWithSignature("emitArg(uint256)", 42)
        });
        bytes memory cData = abi.encode(callObj);

        // check emissions, should work
        vm.expectEmit(true, true, true, true);
        emit CallExecuted(callObj);
        emit ProxyExecuted(address(proxy), callObj);
        proxy.execute(cData);
    }

    // ensure executions as random address from the laminator do not work
    function testExecuteAsRandomAddressFromLaminator() public {
        LaminatedProxy proxy = LaminatedProxy(payable(laminator.getOrCreateProxy()));
        Dummy dummy = new Dummy();
        CallObject memory callObj = CallObject({
            amount: 0,
            addr: address(dummy),
            gas: gasleft(),
            callvalue: abi.encodeWithSignature("emitArg(uint256)", 42)
        });
        bytes memory cData = abi.encode(callObj);

        // pretend to be a random address and call directly, should fail
        vm.prank(randomFriendAddress);
        try proxy.execute(cData) {
            assert(false);
        } catch Error(string memory reason) {
            assertEq(reason, "Proxy: Not the owner");
        }
    }

    // ensure executions as laminator from the laminator do not work
    function testExecuteAsLaminatorAddressFromLaminator() public {
        LaminatedProxy proxy = LaminatedProxy(payable(laminator.getOrCreateProxy()));
        Dummy dummy = new Dummy();
        CallObject memory callObj = CallObject({
            amount: 0,
            addr: address(dummy),
            gas: gasleft(),
            callvalue: abi.encodeWithSignature("emitArg(uint256)", 42)
        });
        bytes memory cData = abi.encode(callObj);

        // pretend to be laminator and call directly, should fail
        vm.prank(address(laminator));
        try proxy.execute(cData) {
            assert(false);
        } catch Error(string memory reason) {
            assertEq(reason, "Proxy: Not the owner");
        }
    }
}
