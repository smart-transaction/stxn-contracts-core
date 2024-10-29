// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

import "forge-std/Test.sol";

import {SmarterContract} from "src/timetravel/SmarterContract.sol";
import {CallBreaker, CallObject, ReturnObject, AdditionalData} from "src/timetravel/CallBreaker.sol";
import {Laminator, SolverData} from "src/lamination/Laminator.sol";
import {SmarterContractHarness} from "test/contracts/SmarterContractHarness.sol";
import {CallBreakerHarness} from "test/contracts/CallBreakerHarness.sol";
import {Dummy} from "./utils/Dummy.sol";
import {Constants} from "test/utils/Constants.sol";

contract SmarterContractTest is Test {
    bytes32 public constant DEFAULT_CODE = keccak256(abi.encode("DEFAULT_CODE"));

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
        CallObject[] memory callObjs = new CallObject[](1);
        ReturnObject[] memory returnObjs = new ReturnObject[](1);
        callbreakerHarness.setPortalOpen(callObjs, returnObjs);

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

        SolverData[] memory dataValues = Constants.emptyDataValues();

        vm.prank(pusher, pusher);
        laminator.pushToProxy(abi.encode(pusherCallObjs), 0, DEFAULT_CODE, dataValues);

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

        AdditionalData[] memory associatedData = new AdditionalData[](0);

        AdditionalData[] memory hintdices = new AdditionalData[](2);
        hintdices[0] = AdditionalData({key: keccak256(abi.encode(callObjs[0])), value: abi.encode(0)});
        hintdices[1] = AdditionalData({key: keccak256(abi.encode(callObjs[1])), value: abi.encode(1)});

        vm.prank(address(0xdeadbeef), address(0xdeadbeef));
        callbreaker.executeAndVerify(
            abi.encode(callObjs), abi.encode(returnObjs), abi.encode(associatedData), abi.encode(hintdices)
        );
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

        SolverData[] memory dataValues = Constants.emptyDataValues();

        vm.prank(pusher, pusher);
        laminator.pushToProxy(abi.encode(pusherCallObjs), 0, DEFAULT_CODE, dataValues);

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

        AdditionalData[] memory associatedData = new AdditionalData[](0);

        AdditionalData[] memory hintdices = new AdditionalData[](2);
        hintdices[0] = AdditionalData({key: keccak256(abi.encode(callObjs[0])), value: abi.encode(0)});
        hintdices[1] = AdditionalData({key: keccak256(abi.encode(callObjs[1])), value: abi.encode(1)});

        vm.prank(address(0xdeadbeef), address(0xdeadbeef));
        callbreaker.executeAndVerify(
            abi.encode(callObjs), abi.encode(returnObjs), abi.encode(associatedData), abi.encode(hintdices)
        );
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

        SolverData[] memory dataValues = Constants.emptyDataValues();

        vm.prank(pusher, pusher);
        laminator.pushToProxy(abi.encode(pusherCallObjs), 0, DEFAULT_CODE, dataValues);

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

        AdditionalData[] memory associatedData = new AdditionalData[](0);

        AdditionalData[] memory hintdices = new AdditionalData[](2);
        hintdices[0] = AdditionalData({key: keccak256(abi.encode(callObjs[0])), value: abi.encode(0)});
        hintdices[1] = AdditionalData({key: keccak256(abi.encode(callObjs[1])), value: abi.encode(1)});

        vm.prank(address(0xdeadbeef), address(0xdeadbeef));
        callbreaker.executeAndVerify(
            abi.encode(callObjs), abi.encode(returnObjs), abi.encode(associatedData), abi.encode(hintdices)
        );
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

        SolverData[] memory dataValues = Constants.emptyDataValues();

        vm.prank(pusher, pusher);
        laminator.pushToProxy(abi.encode(pusherCallObjs), 0, DEFAULT_CODE, dataValues);

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

        AdditionalData[] memory associatedData = new AdditionalData[](0);

        AdditionalData[] memory hintdices = new AdditionalData[](2);
        hintdices[0] = AdditionalData({key: keccak256(abi.encode(callObjs[0])), value: abi.encode(0)});
        hintdices[1] = AdditionalData({key: keccak256(abi.encode(callObjs[1])), value: abi.encode(1)});

        vm.prank(address(0xdeadbeef), address(0xdeadbeef));
        callbreaker.executeAndVerify(
            abi.encode(callObjs), abi.encode(returnObjs), abi.encode(associatedData), abi.encode(hintdices)
        );
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

        SolverData[] memory dataValues = Constants.emptyDataValues();

        vm.prank(pusher, pusher);
        laminator.pushToProxy(abi.encode(pusherCallObjs), 0, DEFAULT_CODE, dataValues);

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

        AdditionalData[] memory associatedData = new AdditionalData[](0);

        AdditionalData[] memory hintdices = new AdditionalData[](2);
        hintdices[0] = AdditionalData({key: keccak256(abi.encode(callObjs[0])), value: abi.encode(0)});
        hintdices[1] = AdditionalData({key: keccak256(abi.encode(callObjs[1])), value: abi.encode(1)});

        vm.prank(address(0xdeadbeef), address(0xdeadbeef));
        callbreaker.executeAndVerify(
            abi.encode(callObjs), abi.encode(returnObjs), abi.encode(associatedData), abi.encode(hintdices)
        );

        callbreakerHarness.setPortalOpen(callObjs, returnObjs);

        // Expect a revert with FutureCallExpected error when asserting the future call
        vm.expectRevert(SmarterContract.FutureCallExpected.selector);
        smarterContractWithCallBreakerHarness.assertFutureCallTestHarness();
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

        SolverData[] memory dataValues = Constants.emptyDataValues();

        vm.prank(pusher, pusher);
        laminator.pushToProxy(abi.encode(pusherCallObjs), 0, DEFAULT_CODE, dataValues);

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

        AdditionalData[] memory associatedData = new AdditionalData[](0);

        AdditionalData[] memory hintdices = new AdditionalData[](2);
        hintdices[0] = AdditionalData({key: keccak256(abi.encode(callObjs[0])), value: abi.encode(0)});
        hintdices[1] = AdditionalData({key: keccak256(abi.encode(callObjs[1])), value: abi.encode(1)});

        vm.prank(address(0xdeadbeef), address(0xdeadbeef));
        callbreaker.executeAndVerify(
            abi.encode(callObjs), abi.encode(returnObjs), abi.encode(associatedData), abi.encode(hintdices)
        );

        uint256 callLength = 3;
        uint256 executeIndex = 2;
        setupAndExecuteDummyCall(callLength, executeIndex);

        callbreakerHarness.setPortalOpen(callObjs, returnObjs);
        // Expect a revert with FutureCallExpected error when asserting the future call
        vm.expectRevert(SmarterContract.FutureCallExpected.selector);
        smarterContractWithCallBreakerHarness.assertFutureCallWithIndexTestHarness();

        callLength = 3;
        executeIndex = 1;
        setupAndExecuteDummyCall(callLength, executeIndex);

        callbreakerHarness.setPortalOpen(callObjs, returnObjs);

        // Expect a revert with CallMismatch error when asserting the future call
        vm.expectRevert(SmarterContract.CallMismatch.selector);
        smarterContractWithCallBreakerHarness.assertFutureCallWithIndexTestHarness();
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

        SolverData[] memory dataValues = Constants.emptyDataValues();

        vm.prank(pusher, pusher);
        laminator.pushToProxy(abi.encode(pusherCallObjs), 0, DEFAULT_CODE, dataValues);

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

        AdditionalData[] memory associatedData = new AdditionalData[](0);

        AdditionalData[] memory hintdices = new AdditionalData[](2);
        hintdices[0] = AdditionalData({key: keccak256(abi.encode(callObjs[0])), value: abi.encode(0)});
        hintdices[1] = AdditionalData({key: keccak256(abi.encode(callObjs[1])), value: abi.encode(1)});

        vm.prank(address(0xdeadbeef), address(0xdeadbeef));
        callbreaker.executeAndVerify(
            abi.encode(callObjs), abi.encode(returnObjs), abi.encode(associatedData), abi.encode(hintdices)
        );

        uint256 callLength = 3;
        uint256 executeIndex = 2;
        setupAndExecuteDummyCall(callLength, executeIndex);

        callbreakerHarness.setPortalOpen(callObjs, returnObjs);
        // Expect a revert with the CallMismatch error when asserting the next call
        vm.expectRevert(SmarterContract.CallMismatch.selector);
        smarterContractWithCallBreakerHarness.assertNextCallTestHarness();
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

        callbreakerHarness.setPortalOpen(calls, returnValues);
        callbreakerHarness.resetTraceStoresWithHarness(calls, returnValues);
        callbreakerHarness.populateCallIndicesHarness();

        for (uint256 j = 0; j < executeIndex; j++) {
            callbreakerHarness._executeAndVerifyCallHarness(j);
        }
    }
}
