// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.6.2 <0.9.0;

import "forge-std/Test.sol";
//import {VmSafe} from "forge-std/Vm.sol";

import "../src/timetravel/SmarterContract.sol";
import "../src/timetravel/CallBreaker.sol";
import "../src/lamination/Laminator.sol";

contract SmarterContractHarness is SmarterContract {
    constructor(address callbreakerAddress) SmarterContract(callbreakerAddress) {}

    function dummyFutureCall() public pure returns (bool) {
        return true;
    }

    function assertFutureCallTestHarness() public view {
        CallObject[] memory callObjs = new CallObject[](1);
        callObjs[0] = CallObject({
            amount: 0,
            addr: address(this),
            gas: 1000000,
            callvalue: abi.encodeWithSignature("dummyFutureCall()")
        });

        assertFutureCallTo(callObjs[0]);
    }

    function assertFutureCallWithIndexTestHarness() public view {
        CallObject[] memory callObjs = new CallObject[](1);
        callObjs[0] = CallObject({
            amount: 0,
            addr: address(this),
            gas: 1000000,
            callvalue: abi.encodeWithSignature("dummyFutureCall()")
        });

        assertFutureCallTo(callObjs[0], 1);
    }

    function assertNextCallTestHarness() public view {
        CallObject[] memory callObjs = new CallObject[](1);
        callObjs[0] = CallObject({
            amount: 0,
            addr: address(this),
            gas: 1000000,
            callvalue: abi.encodeWithSignature("dummyFutureCall()")
        });

        assertNextCallTo(callObjs[0]);
    }
}

contract SmarterContractTest is Test {
    CallBreaker public callbreaker;
    SmarterContractHarness public smarterContract;
    Laminator public laminator;
    address payable public pusherLaminated;
    address pusher;

    function setUp() public {
        pusher = address(100);
        callbreaker = new CallBreaker();
        laminator = new Laminator(address(callbreaker));
        smarterContract = new SmarterContractHarness(address(callbreaker));
        pusherLaminated = payable(laminator.computeProxyAddress(pusher));
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
}
