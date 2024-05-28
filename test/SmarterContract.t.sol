// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.6.2 <0.9.0;

import "forge-std/Test.sol";

import {SmarterContract} from "src/timetravel/SmarterContract.sol";
import {CallBreaker, CallObject, ReturnObject} from "src/timetravel/CallBreaker.sol";
import {Laminator} from "src/lamination/Laminator.sol";
import {SmarterContractHarness} from "test/contracts/SmarterContractHarness.sol";
import {CallBreakerHarness} from "test/contracts/CallBreakerHarness.sol";
import {Dummy} from "./utils/Dummy.sol";

contract SmarterContractTest is Test {
    CallBreaker public callbreaker;
    CallBreakerHarness callbreakerHarness = new CallBreakerHarness();
    SmarterContractHarness public smarterContract;
    SmarterContractHarness public smarterContractWithCallBreakerHarness =
        new SmarterContractHarness(address(callbreakerHarness));
    Laminator public laminator;
    Dummy public dummy;
    address payable public pusherLaminated;
    address pusher;

    function setUp() public {
        pusher = address(100);
        callbreaker = new CallBreaker();
        laminator = new Laminator(address(callbreaker));
        smarterContract = new SmarterContractHarness(address(callbreaker));
        pusherLaminated = payable(laminator.computeProxyAddress(pusher));
        dummy = new Dummy();
    }

    function testInitialize() public {
        address _callbreaker = address(1);
        SmarterContract sc = new SmarterContract(_callbreaker);

        assertTrue(_callbreaker == address(sc.callbreaker()));
    }

    function testInitializeFail() public {
        address _callbreaker = address(0);
        vm.expectRevert(SmarterContract.AddressZero.selector);
        new SmarterContract(_callbreaker);
    }

    function testOnlyPortalOpenModifier() public {
        callbreakerHarness.setPortalOpen();

        // should not revert
        smarterContractWithCallBreakerHarness.dummyCallWhenPortalOpen();
    }

    function testOnlyPortalOpenRevert() public {
        vm.expectRevert(SmarterContract.PortalClosed.selector);
        smarterContractWithCallBreakerHarness.dummyCallWhenPortalOpen();
    }

    function testNoFrontRunModifier() public {
        uint256 callLength = 1;
        uint256 executeIndex = 1;

        setupAndExecuteDummyCall(callLength, executeIndex);

        // should not revert
        smarterContractWithCallBreakerHarness.dummyCallNoFrontRun();
    }

    function testNoFrontRunModifierRevert() public {
        uint256 callLength = 3;
        uint256 executeIndex = 2;

        setupAndExecuteDummyCall(callLength, executeIndex);

        vm.expectRevert(SmarterContract.IllegalFrontrun.selector);
        smarterContractWithCallBreakerHarness.dummyCallNoFrontRun();
    }

    function testNoBackRunModifier() public {
        uint256 callLength = 2;
        uint256 executeIndex = 2;

        setupAndExecuteDummyCall(callLength, executeIndex);

        // should not revert
        smarterContractWithCallBreakerHarness.dummyCallNoBackRun();
    }

    function testNoBackRunModifierRevert() public {
        uint256 callLength = 2;
        uint256 executeIndex = 1;

        setupAndExecuteDummyCall(callLength, executeIndex);

        vm.expectRevert(SmarterContract.IllegalBackrun.selector);
        smarterContractWithCallBreakerHarness.dummyCallNoBackRun();
    }

    function testFrontrunBlocker() external {
        // send proxy some eth
        pusherLaminated.transfer(1 ether);

        // Userland operations
        CallObject[] memory pusherCallObjs = new CallObject[](1);
        pusherCallObjs[0] = CallObject({
            amount: 0,
            addr: address(smarterContract),
            gas: 10000000,
            callvalue: abi.encodeWithSignature("frontrunBlocker()")
        });

        vm.prank(pusher);
        laminator.pushToProxy(abi.encode(pusherCallObjs), 0);

        CallObject[] memory callObjs = new CallObject[](2);
        ReturnObject[] memory returnObjs = new ReturnObject[](2);

        callObjs[0] = CallObject({
            amount: 0,
            addr: pusherLaminated,
            gas: 10000000,
            callvalue: abi.encodeWithSignature("pull(uint256)", 0)
        });
        // Blank Callobj
        callObjs[1] = CallObject({amount: 0, addr: address(0xbabe), gas: 1000000, callvalue: ""});

        ReturnObject[] memory returnObjsFromPull = new ReturnObject[](1);
        returnObjsFromPull[0] = ReturnObject({returnvalue: ""});

        returnObjs[0] = ReturnObject({returnvalue: abi.encode(abi.encode(returnObjsFromPull))});
        returnObjs[1] = ReturnObject({returnvalue: ""});

        bytes32[] memory keys = new bytes32[](0);
        bytes[] memory values = new bytes[](0);
        bytes memory encodedData = abi.encode(keys, values);

        bytes32[] memory hintdicesKeys = new bytes32[](1);
        hintdicesKeys[0] = keccak256(abi.encode(callObjs[0]));
        uint256[] memory hintindicesVals = new uint256[](1);
        hintindicesVals[0] = 0;
        bytes memory hintdices = abi.encode(hintdicesKeys, hintindicesVals);

        vm.prank(address(0xdeadbeef));
        callbreaker.verify(abi.encode(callObjs), abi.encode(returnObjs), encodedData, hintdices);
    }

    function testFail_FrontrunBlocker() external {
        // send proxy some eth
        pusherLaminated.transfer(1 ether);

        // Userland operations
        CallObject[] memory pusherCallObjs = new CallObject[](1);
        pusherCallObjs[0] = CallObject({
            amount: 0,
            addr: address(smarterContract),
            gas: 10000000,
            callvalue: abi.encodeWithSignature("frontrunBlocker()")
        });

        vm.prank(pusher);
        laminator.pushToProxy(abi.encode(pusherCallObjs), 0);

        CallObject[] memory callObjs = new CallObject[](2);
        ReturnObject[] memory returnObjs = new ReturnObject[](2);

        // Blank Callobj
        callObjs[0] = CallObject({amount: 0, addr: address(0xbabe), gas: 1000000, callvalue: ""});

        callObjs[1] = CallObject({
            amount: 0,
            addr: pusherLaminated,
            gas: 10000000,
            callvalue: abi.encodeWithSignature("pull(uint256)", 0)
        });

        ReturnObject[] memory returnObjsFromPull = new ReturnObject[](1);
        returnObjsFromPull[0] = ReturnObject({returnvalue: ""});

        returnObjs[0] = ReturnObject({returnvalue: ""});
        returnObjs[1] = ReturnObject({returnvalue: abi.encode(abi.encode(returnObjsFromPull))});

        bytes32[] memory keys = new bytes32[](0);
        bytes[] memory values = new bytes[](0);
        bytes memory encodedData = abi.encode(keys, values);

        bytes32[] memory hintdicesKeys = new bytes32[](1);
        hintdicesKeys[0] = keccak256(abi.encode(callObjs[0]));
        uint256[] memory hintindicesVals = new uint256[](1);
        hintindicesVals[0] = 0;
        bytes memory hintdices = abi.encode(hintdicesKeys, hintindicesVals);

        vm.prank(address(0xdeadbeef));
        callbreaker.verify(abi.encode(callObjs), abi.encode(returnObjs), encodedData, hintdices);
    }

    function testBackrunBlocker() external {
        // send proxy some eth
        pusherLaminated.transfer(1 ether);

        // Userland operations
        CallObject[] memory pusherCallObjs = new CallObject[](1);
        pusherCallObjs[0] = CallObject({
            amount: 0,
            addr: address(smarterContract),
            gas: 10000000,
            callvalue: abi.encodeWithSignature("backrunBlocker()")
        });

        vm.prank(pusher);
        laminator.pushToProxy(abi.encode(pusherCallObjs), 0);

        CallObject[] memory callObjs = new CallObject[](2);
        ReturnObject[] memory returnObjs = new ReturnObject[](2);

        // Blank Callobj
        callObjs[0] = CallObject({amount: 0, addr: address(0xbabe), gas: 1000000, callvalue: ""});

        callObjs[1] = CallObject({
            amount: 0,
            addr: pusherLaminated,
            gas: 10000000,
            callvalue: abi.encodeWithSignature("pull(uint256)", 0)
        });

        ReturnObject[] memory returnObjsFromPull = new ReturnObject[](1);
        returnObjsFromPull[0] = ReturnObject({returnvalue: ""});

        returnObjs[0] = ReturnObject({returnvalue: ""});
        returnObjs[1] = ReturnObject({returnvalue: abi.encode(abi.encode(returnObjsFromPull))});

        bytes32[] memory keys = new bytes32[](0);
        bytes[] memory values = new bytes[](0);
        bytes memory encodedData = abi.encode(keys, values);

        bytes32[] memory hintdicesKeys = new bytes32[](1);
        hintdicesKeys[0] = keccak256(abi.encode(callObjs[0]));
        uint256[] memory hintindicesVals = new uint256[](1);
        hintindicesVals[0] = 0;
        bytes memory hintdices = abi.encode(hintdicesKeys, hintindicesVals);

        vm.prank(address(0xdeadbeef));
        callbreaker.verify(abi.encode(callObjs), abi.encode(returnObjs), encodedData, hintdices);
    }

    function testFail_BackrunBlocker() external {
        // send proxy some eth
        pusherLaminated.transfer(1 ether);

        // Userland operations
        CallObject[] memory pusherCallObjs = new CallObject[](1);
        pusherCallObjs[0] = CallObject({
            amount: 0,
            addr: address(smarterContract),
            gas: 10000000,
            callvalue: abi.encodeWithSignature("backrunBlocker()")
        });

        vm.prank(pusher);
        laminator.pushToProxy(abi.encode(pusherCallObjs), 0);

        CallObject[] memory callObjs = new CallObject[](2);
        ReturnObject[] memory returnObjs = new ReturnObject[](2);

        callObjs[0] = CallObject({
            amount: 0,
            addr: pusherLaminated,
            gas: 10000000,
            callvalue: abi.encodeWithSignature("pull(uint256)", 0)
        });

        // Blank Callobj
        callObjs[1] = CallObject({amount: 0, addr: address(0xbabe), gas: 1000000, callvalue: ""});

        ReturnObject[] memory returnObjsFromPull = new ReturnObject[](1);
        returnObjsFromPull[0] = ReturnObject({returnvalue: ""});

        returnObjs[0] = ReturnObject({returnvalue: abi.encode(abi.encode(returnObjsFromPull))});
        returnObjs[1] = ReturnObject({returnvalue: ""});

        bytes32[] memory keys = new bytes32[](0);
        bytes[] memory values = new bytes[](0);
        bytes memory encodedData = abi.encode(keys, values);

        bytes32[] memory hintdicesKeys = new bytes32[](1);
        hintdicesKeys[0] = keccak256(abi.encode(callObjs[0]));
        uint256[] memory hintindicesVals = new uint256[](1);
        hintindicesVals[0] = 0;
        bytes memory hintdices = abi.encode(hintdicesKeys, hintindicesVals);

        vm.prank(address(0xdeadbeef));
        callbreaker.verify(abi.encode(callObjs), abi.encode(returnObjs), encodedData, hintdices);
    }

    function testAssertFutureCallTo() external {
        // send proxy some eth
        pusherLaminated.transfer(1 ether);

        // Userland operations
        CallObject[] memory pusherCallObjs = new CallObject[](1);
        pusherCallObjs[0] = CallObject({
            amount: 0,
            addr: address(smarterContract),
            gas: 10000000,
            callvalue: abi.encodeWithSignature("assertFutureCallTestHarness()")
        });

        vm.prank(pusher);
        laminator.pushToProxy(abi.encode(pusherCallObjs), 0);

        CallObject[] memory callObjs = new CallObject[](2);
        ReturnObject[] memory returnObjs = new ReturnObject[](2);

        callObjs[0] = CallObject({
            amount: 0,
            addr: pusherLaminated,
            gas: 10000000,
            callvalue: abi.encodeWithSignature("pull(uint256)", 0)
        });

        // Blank Callobj
        callObjs[1] = CallObject({
            amount: 0,
            addr: address(smarterContract),
            gas: 1000000,
            callvalue: abi.encodeWithSignature("dummyFutureCall()")
        });

        ReturnObject[] memory returnObjsFromPull = new ReturnObject[](1);
        returnObjsFromPull[0] = ReturnObject({returnvalue: ""});

        returnObjs[0] = ReturnObject({returnvalue: abi.encode(abi.encode(returnObjsFromPull))});
        returnObjs[1] = ReturnObject({returnvalue: abi.encode(true)});

        bytes32[] memory keys = new bytes32[](0);
        bytes[] memory values = new bytes[](0);
        bytes memory encodedData = abi.encode(keys, values);

        bytes32[] memory hintdicesKeys = new bytes32[](2);
        hintdicesKeys[0] = keccak256(abi.encode(callObjs[0]));
        hintdicesKeys[1] = keccak256(abi.encode(callObjs[1]));
        uint256[] memory hintindicesVals = new uint256[](2);
        hintindicesVals[0] = 0;
        hintindicesVals[1] = 1;
        bytes memory hintdices = abi.encode(hintdicesKeys, hintindicesVals);

        vm.prank(address(0xdeadbeef));
        callbreaker.verify(abi.encode(callObjs), abi.encode(returnObjs), encodedData, hintdices);
    }

    function testAssertFutureCallToWithIndex() external {
        // send proxy some eth
        pusherLaminated.transfer(1 ether);

        // Userland operations
        CallObject[] memory pusherCallObjs = new CallObject[](1);
        pusherCallObjs[0] = CallObject({
            amount: 0,
            addr: address(smarterContract),
            gas: 10000000,
            callvalue: abi.encodeWithSignature("assertFutureCallWithIndexTestHarness()")
        });

        vm.prank(pusher);
        laminator.pushToProxy(abi.encode(pusherCallObjs), 0);

        CallObject[] memory callObjs = new CallObject[](2);
        ReturnObject[] memory returnObjs = new ReturnObject[](2);

        callObjs[0] = CallObject({
            amount: 0,
            addr: pusherLaminated,
            gas: 10000000,
            callvalue: abi.encodeWithSignature("pull(uint256)", 0)
        });

        // Blank Callobj
        callObjs[1] = CallObject({
            amount: 0,
            addr: address(smarterContract),
            gas: 1000000,
            callvalue: abi.encodeWithSignature("dummyFutureCall()")
        });

        ReturnObject[] memory returnObjsFromPull = new ReturnObject[](1);
        returnObjsFromPull[0] = ReturnObject({returnvalue: ""});

        returnObjs[0] = ReturnObject({returnvalue: abi.encode(abi.encode(returnObjsFromPull))});
        returnObjs[1] = ReturnObject({returnvalue: abi.encode(true)});

        bytes32[] memory keys = new bytes32[](0);
        bytes[] memory values = new bytes[](0);
        bytes memory encodedData = abi.encode(keys, values);

        bytes32[] memory hintdicesKeys = new bytes32[](2);
        hintdicesKeys[0] = keccak256(abi.encode(callObjs[0]));
        hintdicesKeys[1] = keccak256(abi.encode(callObjs[1]));
        uint256[] memory hintindicesVals = new uint256[](2);
        hintindicesVals[0] = 0;
        hintindicesVals[1] = 1;
        bytes memory hintdices = abi.encode(hintdicesKeys, hintindicesVals);

        vm.prank(address(0xdeadbeef));
        callbreaker.verify(abi.encode(callObjs), abi.encode(returnObjs), encodedData, hintdices);
    }

    function testAssertNextCallTo() external {
        // send proxy some eth
        pusherLaminated.transfer(1 ether);

        // Userland operations
        CallObject[] memory pusherCallObjs = new CallObject[](1);
        pusherCallObjs[0] = CallObject({
            amount: 0,
            addr: address(smarterContract),
            gas: 10000000,
            callvalue: abi.encodeWithSignature("assertFutureCallTestHarness()")
        });

        vm.prank(pusher);
        laminator.pushToProxy(abi.encode(pusherCallObjs), 0);

        CallObject[] memory callObjs = new CallObject[](2);
        ReturnObject[] memory returnObjs = new ReturnObject[](2);

        callObjs[0] = CallObject({
            amount: 0,
            addr: pusherLaminated,
            gas: 10000000,
            callvalue: abi.encodeWithSignature("pull(uint256)", 0)
        });

        // Blank Callobj
        callObjs[1] = CallObject({
            amount: 0,
            addr: address(smarterContract),
            gas: 1000000,
            callvalue: abi.encodeWithSignature("dummyFutureCall()")
        });

        ReturnObject[] memory returnObjsFromPull = new ReturnObject[](1);
        returnObjsFromPull[0] = ReturnObject({returnvalue: ""});

        returnObjs[0] = ReturnObject({returnvalue: abi.encode(abi.encode(returnObjsFromPull))});
        returnObjs[1] = ReturnObject({returnvalue: abi.encode(true)});

        bytes32[] memory keys = new bytes32[](0);
        bytes[] memory values = new bytes[](0);
        bytes memory encodedData = abi.encode(keys, values);

        bytes32[] memory hintdicesKeys = new bytes32[](2);
        hintdicesKeys[0] = keccak256(abi.encode(callObjs[0]));
        hintdicesKeys[1] = keccak256(abi.encode(callObjs[1]));
        uint256[] memory hintindicesVals = new uint256[](2);
        hintindicesVals[0] = 0;
        hintindicesVals[1] = 1;
        bytes memory hintdices = abi.encode(hintdicesKeys, hintindicesVals);

        vm.prank(address(0xdeadbeef));
        callbreaker.verify(abi.encode(callObjs), abi.encode(returnObjs), encodedData, hintdices);
    }

    function testGetCurrentExecutingPair() public {
        uint256 callLength = 3;
        uint256 executeIndex = 2;

        (CallObject[] memory calls, ReturnObject[] memory returnValues) =
            setupAndExecuteDummyCall(callLength, executeIndex);
        (CallObject memory callObj, ReturnObject memory returnObj) =
            smarterContractWithCallBreakerHarness.getCurrentExecutingPair();

        assertEq(keccak256(callObj.callvalue), keccak256((calls[executeIndex - 1].callvalue)));
        assertEq(keccak256(returnObj.returnvalue), keccak256((returnValues[executeIndex - 1].returnvalue)));
    }

    function testSoloExecuteBlocker() public {
        uint256 callLength = 1;
        uint256 executeIndex = 1;

        setupAndExecuteDummyCall(callLength, executeIndex);

        // should not revert
        smarterContractWithCallBreakerHarness.soloExecuteBlocker();
    }

    function testSoloExecuteBlockerFrontRunRevert() public {
        uint256 callLength = 3;
        uint256 executeIndex = 2;

        setupAndExecuteDummyCall(callLength, executeIndex);
        vm.expectRevert(SmarterContract.IllegalFrontrun.selector);
        smarterContractWithCallBreakerHarness.soloExecuteBlocker();
    }

    function testSoloExecuteBlockerBackRunRevert() public {
        uint256 callLength = 3;
        uint256 executeIndex = 1;

        setupAndExecuteDummyCall(callLength, executeIndex);
        vm.expectRevert(SmarterContract.IllegalBackrun.selector);
        smarterContractWithCallBreakerHarness.soloExecuteBlocker();
    }

    function setupAndExecuteDummyCall(uint256 callLength, uint256 executeIndex)
        internal
        returns (CallObject[] memory calls, ReturnObject[] memory returnValues)
    {
        calls = new CallObject[](callLength);
        returnValues = new ReturnObject[](callLength);

        for (uint256 i = 0; i < callLength; i++) {
            calls[i] = CallObject({
                amount: 0,
                addr: address(dummy),
                gas: 1000000,
                callvalue: abi.encodeWithSignature("returnVal(uint256)", i)
            });

            returnValues[i] = ReturnObject({returnvalue: abi.encodePacked(uint256(i))});
        }

        callbreakerHarness.setPortalOpen();
        callbreakerHarness.resetTraceStoresWithHarness(calls, returnValues);
        callbreakerHarness.populateCallIndicesHarness();

        for (uint256 j = 0; j < executeIndex; j++) {
            callbreakerHarness._executeAndVerifyCallHarness(j);
        }
    }
}
